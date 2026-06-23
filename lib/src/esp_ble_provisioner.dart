import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'ble/esp_ble_transport.dart';
import 'ble/web_esp_ble_transport.dart';
import 'endpoint_uuids.dart';
import 'models.dart';
import 'prov/proto_commands.dart' as commands;
import 'proto/protos.dart' as pb;
import 'provisioner_error.dart';
import 'security/security.dart';
import 'security/security0.dart';

const String provSessionEndpoint = 'prov-session';
const String provScanEndpoint = 'prov-scan';
const String provConfigEndpoint = 'prov-config';
const String provCtrlEndpoint = 'prov-ctrl';
const String protoVerEndpoint = 'proto-ver';

class EspBleProvisioner {
  EspBleProvisioner({
    this.serviceUuid = defaultEspProvisioningServiceUuid,
    this.deviceNamePrefix = 'PROV_',
    Security? security,
    Map<String, String> endpointUuids = const {},
    EspBleTransport? transport,
    this.requestAndroidFineLocation = false,
    this.mtu = 517,
    this.responseDelay = const Duration(milliseconds: 200),
    this.logPayloads = false,
    void Function(String message)? onLog,
  }) : security = security ?? const Security0(),
       _transport =
           transport ??
           (kIsWeb
               ? WebEspBleTransport(serviceUuid: serviceUuid)
               : const UniversalBleTransport()),
       _onLog = onLog,
       _explicitEndpointNames = endpointUuids.keys.toSet(),
       _endpointUuids = {
         ...deriveEspProvisioningEndpointUuids(serviceUuid),
         ...endpointUuids,
       };

  final String serviceUuid;
  final String deviceNamePrefix;
  final Security security;
  final bool requestAndroidFineLocation;
  final int mtu;
  final Duration responseDelay;
  final bool logPayloads;
  final EspBleTransport _transport;
  final void Function(String message)? _onLog;
  final Set<String> _explicitEndpointNames;
  final Map<String, String> _endpointUuids;
  String? _resolvedServiceUuid;

  EspBleDevice? _device;
  bool _connected = false;

  EspBleDevice? get device => _device;
  bool get isConnected => _connected && _device != null;
  Map<String, String> get endpointUuids => Map.unmodifiable(_endpointUuids);

  Future<List<EspBleDevice>> scanDevices({
    Duration duration = const Duration(seconds: 8),
    List<String>? serviceUuids,
  }) async {
    final devices = <String, EspBleDevice>{};
    final subscription = _transport.scanStream.listen((device) {
      final name = device.name ?? device.rawName;
      if (name == null || !name.startsWith(deviceNamePrefix)) return;
      devices[device.deviceId] = EspBleDevice(id: device.deviceId, name: name);
    });

    await _transport.requestPermissions(
      withAndroidFineLocation: requestAndroidFineLocation,
    );
    await _transport.startScan(
      scanFilter: ScanFilter(
        withNamePrefix: [deviceNamePrefix],
        withServices: serviceUuids ?? const [],
      ),
      platformConfig:
          kIsWeb
              ? PlatformConfig(web: WebOptions(optionalServices: [serviceUuid]))
              : null,
    );

    try {
      await Future<void>.delayed(duration);
    } finally {
      await _transport.stopScan();
      await subscription.cancel();
    }

    return devices.values.toList(growable: false);
  }

  Future<EspBleDevice> connect({
    EspBleDevice? device,
    Duration scanDuration = const Duration(seconds: 8),
    Duration connectionTimeout = const Duration(seconds: 60),
  }) async {
    final target = device ?? await _findFirstDevice(scanDuration);
    await _transport.stopScan();
    try {
      await _transport.connect(target.id, timeout: connectionTimeout);
      _device = target;
      _connected = true;
      await _requestMtu(target.id);
      await _discoverProvisioningService();
      return target;
    } catch (_) {
      await _cleanupFailedConnection(target.id);
      rethrow;
    }
  }

  Future<void> disconnect({Duration? timeout}) async {
    final deviceId = _device?.id;
    if (deviceId != null) {
      try {
        await _transport.disconnect(deviceId, timeout: timeout);
      } finally {
        _clearConnectionState();
      }
      return;
    }
    _clearConnectionState();
  }

  Future<void> establishSession() async {
    _ensureConnected();

    final setup0 = await security.setup0Request();
    _log('Security setup0 request: ${setup0.length} bytes');
    await _writeEndpoint(provSessionEndpoint, setup0);
    await Future<void>.delayed(responseDelay);
    final setup0Response = await _readEndpoint(provSessionEndpoint);
    _log('Security setup0 response: ${setup0Response.length} bytes');
    try {
      await security.setup0Response(setup0Response);
    } catch (error) {
      throw ProvisionerError(
        'Security setup0 response parse failed: $error. '
        'Response: ${_hexPreview(setup0Response)}',
      );
    }

    final setup1 = await security.setup1Request();
    if (setup1 != null) {
      _log('Security setup1 request: ${setup1.length} bytes');
      await _writeEndpoint(provSessionEndpoint, setup1);
      await Future<void>.delayed(responseDelay);
      final setup1Response = await _readEndpoint(provSessionEndpoint);
      _log('Security setup1 response: ${setup1Response.length} bytes');
      try {
        await security.setup1Response(setup1Response);
      } catch (error) {
        throw ProvisionerError(
          'Security setup1 response parse failed: $error. '
          'Response: ${_hexPreview(setup1Response)}',
        );
      }
    }
  }

  Future<void> ctrlReset() async {
    await _exchange(
      provCtrlEndpoint,
      commands.ctrlResetRequest(),
      'Reset provisioning state',
      commands.ctrlResetResponse,
    );
  }

  Future<void> ctrlReprov() async {
    await _exchange(
      provCtrlEndpoint,
      commands.ctrlReprovRequest(),
      'Re-provision',
      commands.ctrlReprovResponse,
    );
  }

  Future<void> startScan([
    WiFiScanOptions options = const WiFiScanOptions(),
  ]) async {
    await _exchange(
      provScanEndpoint,
      commands.scanStartRequest(options),
      'Start Wi-Fi scan',
      commands.scanStartResponse,
    );
  }

  Future<int> getScanStatus() async {
    return _exchange(
      provScanEndpoint,
      commands.scanStatusRequest(),
      'Get scan status',
      commands.scanStatusResponse,
    );
  }

  Future<List<WiFiNetwork>> getScanResults({
    required int count,
    int startIndex = 0,
  }) async {
    return _exchange(
      provScanEndpoint,
      commands.scanResultRequest(startIndex: startIndex, count: count),
      'Get scan results',
      commands.scanResultResponse,
    );
  }

  Future<List<WiFiNetwork>> scan([
    WiFiScanOptions options = const WiFiScanOptions(),
  ]) async {
    if (!options.blocking) {
      throw const ProvisionerError(
        'Non-blocking Wi-Fi scan is not implemented.',
      );
    }
    await startScan(options);
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var count = 0;
    while (DateTime.now().isBefore(deadline)) {
      count = await getScanStatus();
      if (count > 0) {
        return getScanResults(count: count);
      }
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }
    return const <WiFiNetwork>[];
  }

  Future<WiFiStatus> getWiFiStatus() async {
    return _exchange(
      provConfigEndpoint,
      commands.configGetStatusRequest(),
      'Get Wi-Fi status',
      commands.configGetStatusResponse,
    );
  }

  Future<void> setWiFiConfig(WiFiConfig config) async {
    await _exchange(
      provConfigEndpoint,
      commands.configSetConfigRequest(config),
      'Set Wi-Fi config',
      commands.configSetConfigResponse,
    );
  }

  Future<void> applyWiFiConfig() async {
    await _exchange(
      provConfigEndpoint,
      commands.configApplyConfigRequest(),
      'Apply Wi-Fi config',
      commands.configApplyConfigResponse,
    );
  }

  Future<WiFiStatus> waitForWiFiStatus({
    Duration timeout = const Duration(seconds: 60),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await getWiFiStatus();
      if (status.state == pb.WifiStationState.Connected) return status;
      if (status.state == pb.WifiStationState.ConnectionFailed ||
          status.attemptsRemaining == 0) {
        throw ProvisionerError(
          'Wi-Fi connection failed: ${status.failReason?.name ?? 'no attempts remaining'}',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
    throw ProvisionerError(
      'Wi-Fi connection timed out after ${timeout.inMilliseconds}ms.',
    );
  }

  Future<WiFiStatus> sendCredentials(
    WiFiConfig config, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await setWiFiConfig(config);
    await applyWiFiConfig();
    return waitForWiFiStatus(timeout: timeout);
  }

  Future<void> writeValueToEndpoint(
    String endpointName,
    Uint8List value,
  ) async {
    final encrypted = await security.encrypt(value);
    await _writeEndpoint(endpointName, encrypted);
  }

  Future<Uint8List> readValueFromEndpoint(String endpointName) async {
    final value = await _readEndpoint(endpointName);
    return security.decrypt(value);
  }

  void registerEndpoint(String endpointName, String characteristicUuid) {
    _endpointUuids[endpointName] = characteristicUuid;
  }

  void registerCustomEndpoint(String endpointName, {int index = 0}) {
    final serviceUuid = _resolvedServiceUuid ?? this.serviceUuid;
    registerEndpoint(
      endpointName,
      deriveEspProvisioningCustomEndpointUuid(serviceUuid, index),
    );
  }

  Future<EspBleDevice> _findFirstDevice(Duration scanDuration) async {
    final devices = await scanDevices(duration: scanDuration);
    if (devices.isEmpty) {
      throw ProvisionerError(
        'No ESP provisioning device found with prefix $deviceNamePrefix.',
      );
    }
    return devices.first;
  }

  Future<void> _discoverProvisioningService() async {
    final deviceId = _requireDeviceId();
    final services = await _transport.discoverServices(
      deviceId,
      withDescriptors: true,
    );
    _log(
      'Discovered services: ${services.map((service) => service.uuid).join(', ')}',
    );
    BleService? service;
    for (final candidate in services) {
      if (_sameUuid(candidate.uuid, serviceUuid)) {
        service = candidate;
        break;
      }
    }
    service ??= _findServiceByProvisioningEndpoints(services);
    if (service == null) {
      throw ProvisionerError(
        'Provisioning service not found: $serviceUuid. '
        'Discovered services: ${services.map((service) => service.uuid).join(', ')}.',
      );
    }
    _resolvedServiceUuid = service.uuid;

    final derived = deriveEspProvisioningEndpointUuids(service.uuid);
    for (final entry in derived.entries) {
      if (_explicitEndpointNames.contains(entry.key)) continue;
      _endpointUuids[entry.key] = entry.value;
    }
    _log('Using provisioning service: ${service.uuid}');

    final known = _endpointUuids.values.map(_normalizeUuid).toSet();
    final characteristics = service.characteristics.map((c) => c.uuid).toList();
    _log('Provisioning characteristics: ${characteristics.join(', ')}');
    for (final uuid in known) {
      if (!characteristics.any((c) => _sameUuid(c, uuid))) {
        throw ProvisionerError(
          'Configured endpoint characteristic not found: $uuid.',
        );
      }
    }
  }

  Future<void> _cleanupFailedConnection(String deviceId) async {
    _log('Cleaning up failed connection: $deviceId');
    try {
      await _transport.stopScan();
    } catch (error) {
      _log('Stop scan during cleanup failed: $error');
    }
    try {
      await _transport.disconnect(
        deviceId,
        timeout: const Duration(seconds: 5),
      );
    } catch (error) {
      _log('Disconnect during cleanup failed: $error');
    } finally {
      _clearConnectionState();
    }
  }

  Future<void> _requestMtu(String deviceId) async {
    if (mtu <= 0) return;
    if (kIsWeb) {
      _log('Skipping MTU request on Web platform.');
      return;
    }
    try {
      final negotiated = await _transport.requestMtu(
        deviceId,
        mtu,
        timeout: const Duration(seconds: 5),
      );
      _log('Requested MTU $mtu, negotiated MTU $negotiated');
    } catch (error) {
      _log('MTU request failed: $error');
    }
  }

  BleService? _findServiceByProvisioningEndpoints(List<BleService> services) {
    for (final service in services) {
      final derived = deriveEspProvisioningEndpointUuids(service.uuid);
      final characteristics = service.characteristics.map((c) => c.uuid);
      final hasRequired = [
        provSessionEndpoint,
        provConfigEndpoint,
        provScanEndpoint,
      ].every(
        (endpoint) =>
            characteristics.any((uuid) => _sameUuid(uuid, derived[endpoint]!)),
      );
      if (hasRequired) return service;
    }
    return null;
  }

  Future<Uint8List> _sendEncrypted(
    String endpointName,
    Uint8List plainRequest,
  ) async {
    _ensureConnected();
    final encryptedRequest = await security.encrypt(plainRequest);
    await _writeEndpoint(endpointName, encryptedRequest);
    await Future<void>.delayed(responseDelay);
    final encryptedResponse = await _readEndpoint(endpointName);
    _logPayload(
      'Encrypted response $endpointName: '
      '${encryptedResponse.length} bytes ${_hexPreview(encryptedResponse)}',
    );
    if (_looksLikeProtoVersionResponse(encryptedResponse)) {
      throw ProvisionerError(
        'Endpoint "$endpointName" read proto-ver JSON. Check endpoint UUID '
        'mapping for the connected firmware. Response: '
        '${_asciiPreview(encryptedResponse)}',
      );
    }
    final plainResponse = await security.decrypt(encryptedResponse);
    _logPayload(
      'Decrypted response $endpointName: '
      '${plainResponse.length} bytes ${_hexPreview(plainResponse)}',
    );
    return plainResponse;
  }

  Future<T> _exchange<T>(
    String endpointName,
    Uint8List plainRequest,
    String operation,
    T Function(Uint8List response) parse,
  ) async {
    final response = await _sendEncrypted(endpointName, plainRequest);
    return _parseResponse(operation, response, () => parse(response));
  }

  T _parseResponse<T>(
    String operation,
    Uint8List response,
    T Function() parse,
  ) {
    try {
      return parse();
    } catch (error) {
      throw ProvisionerError(
        '$operation response parse failed: $error. '
        'Response: ${_hexPreview(response)}',
      );
    }
  }

  Future<void> _writeEndpoint(String endpointName, Uint8List value) async {
    final endpoint = _endpoint(endpointName);
    _log(
      'Write $endpointName ${endpoint.characteristicUuid}: '
      '${value.length} bytes ${_hexPreview(value)}',
    );
    await _transport.write(
      _requireDeviceId(),
      endpoint.serviceUuid,
      endpoint.characteristicUuid,
      value,
    );
  }

  Future<Uint8List> _readEndpoint(String endpointName) {
    final endpoint = _endpoint(endpointName);
    _log('Read $endpointName ${endpoint.characteristicUuid}');
    return _transport.read(
      _requireDeviceId(),
      endpoint.serviceUuid,
      endpoint.characteristicUuid,
    );
  }

  BleEndpoint _endpoint(String endpointName) {
    final characteristicUuid = _endpointUuids[endpointName];
    if (characteristicUuid == null || characteristicUuid.isEmpty) {
      throw ProvisionerError(
        'Endpoint "$endpointName" is not registered. Pass endpointUuids when '
        'creating EspBleProvisioner or call registerEndpoint().',
      );
    }
    return BleEndpoint(
      serviceUuid: _resolvedServiceUuid ?? serviceUuid,
      characteristicUuid: characteristicUuid,
    );
  }

  String _requireDeviceId() {
    final deviceId = _device?.id;
    if (!_connected || deviceId == null) {
      throw const ProvisionerError(
        'Not connected to an ESP provisioning device.',
      );
    }
    return deviceId;
  }

  void _ensureConnected() => _requireDeviceId();

  void _clearConnectionState() {
    _connected = false;
    _device = null;
    _resolvedServiceUuid = null;
  }

  bool _sameUuid(String a, String b) => _normalizeUuid(a) == _normalizeUuid(b);

  String _normalizeUuid(String uuid) =>
      BleUuidParser.string(uuid).toLowerCase();

  void _log(String message) => _onLog?.call(message);

  void _logPayload(String message) {
    if (logPayloads) _log(message);
  }

  String _hexPreview(Uint8List bytes, [int maxBytes = 32]) {
    final preview = bytes
        .take(maxBytes)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return bytes.length > maxBytes ? '$preview ...' : preview;
  }

  bool _looksLikeProtoVersionResponse(Uint8List bytes) {
    if (bytes.isEmpty || bytes.first != 0x7b) return false;
    final text = String.fromCharCodes(bytes.take(64));
    return text.contains('"prov"') || text.contains('"ver"');
  }

  String _asciiPreview(Uint8List bytes, [int maxBytes = 96]) {
    final codes = bytes.take(maxBytes).map((byte) {
      if (byte >= 0x20 && byte <= 0x7e) return byte;
      return 0x2e;
    });
    final preview = String.fromCharCodes(codes);
    return bytes.length > maxBytes ? '$preview ...' : preview;
  }
}
