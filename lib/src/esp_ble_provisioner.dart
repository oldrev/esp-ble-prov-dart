import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'ble/esp_ble_transport.dart';
import 'ble/platform_transport.dart'
    if (dart.library.js_interop) 'ble/platform_transport_web.dart';
import 'endpoint_uuids.dart';
import 'models.dart';
import 'prov/proto_commands.dart' as commands;
import 'proto/protos.dart' as pb;
import 'provisioner_error.dart';
import 'security/security.dart';
import 'security/security0.dart';

/// Security handshake endpoint name used by ESP-IDF provisioning firmware.
const String provSessionEndpoint = 'prov-session';

/// Wi-Fi scan endpoint name used by ESP-IDF provisioning firmware.
const String provScanEndpoint = 'prov-scan';

/// Wi-Fi configuration endpoint name used by ESP-IDF provisioning firmware.
const String provConfigEndpoint = 'prov-config';

/// Control endpoint name used by ESP-IDF provisioning firmware.
const String provCtrlEndpoint = 'prov-ctrl';

/// Protocol version endpoint name used by ESP-IDF provisioning firmware.
const String protoVerEndpoint = 'proto-ver';

/// High-level client for ESP BLE Wi-Fi provisioning.
///
/// A typical flow is [scanDevices], [connect], [establishSession], optionally
/// [scan] for nearby networks, then [sendCredentials].
class EspBleProvisioner {
  /// Creates a provisioning client.
  ///
  /// [security] defaults to [Security0]. Use [Security1] for ESP-IDF devices
  /// configured with security version 1. [endpointUuids] can override derived
  /// characteristic UUIDs for custom firmware.
  EspBleProvisioner({
    this.serviceUuid = kDefaultEspProvisioningServiceUuid,
    this.deviceNamePrefix = 'PROV_',
    Security? security,
    Map<String, String> endpointUuids = const {},
    EspBleTransport? transport,
    this.requestAndroidFineLocation = false,
    this.mtu = 517,
    this.responseDelay = const Duration(milliseconds: 200),
    this.responseTimeout = const Duration(seconds: 15),
    this.readRetryInterval = const Duration(milliseconds: 100),
    this.logPayloads = false,
    void Function(String message)? onLog,
  }) : security = security ?? const Security0(),
       _transport = transport ?? createPlatformTransport(serviceUuid),
       _onLog = onLog,
       _explicitEndpointNames = endpointUuids.keys.toSet(),
       _endpointUuids = {
         ...deriveEspProvisioningEndpointUuids(serviceUuid),
         ...endpointUuids,
       };

  /// BLE service UUID advertised by the ESP provisioning service.
  final String serviceUuid;

  /// Device-name prefix used while scanning for provisioning devices.
  final String deviceNamePrefix;

  /// Security scheme used for session setup and endpoint payload encryption.
  final Security security;

  /// Whether Android scans should request fine location permission.
  final bool requestAndroidFineLocation;

  /// Preferred BLE MTU requested after connecting on non-web platforms.
  ///
  /// Set to `0` or a negative value to skip MTU negotiation.
  final int mtu;

  /// Delay inserted between endpoint writes and matching reads.
  ///
  /// This affects all provisioning endpoint exchanges, including
  /// `prov-session`, `prov-scan`, `prov-config`, custom endpoints, and control
  /// endpoints.
  final Duration responseDelay;

  /// Maximum time to wait for a non-empty endpoint response after a write.
  ///
  /// This affects all provisioning endpoint exchanges, including
  /// `prov-session`, `prov-scan`, `prov-config`, custom endpoints, and control
  /// endpoints.
  final Duration responseTimeout;

  /// Delay between response read attempts while waiting for the device.
  ///
  /// This affects all provisioning endpoint exchanges, including
  /// `prov-session`, `prov-scan`, `prov-config`, custom endpoints, and control
  /// endpoints.
  final Duration readRetryInterval;

  /// Whether encrypted and decrypted endpoint payload previews are logged.
  final bool logPayloads;
  final EspBleTransport _transport;
  final void Function(String message)? _onLog;
  final Set<String> _explicitEndpointNames;
  final Map<String, String> _endpointUuids;
  String? _resolvedServiceUuid;
  Set<String>? _discoveredCharacteristicUuids;
  StreamSubscription<bool>? _connectionSubscription;
  Future<void> _operationTail = Future<void>.value();

  EspBleDevice? _device;
  bool _connected = false;

  /// Currently connected device, or `null` when disconnected.
  EspBleDevice? get device => _device;

  /// Whether this provisioner currently has an active BLE connection.
  bool get isConnected => _connected && _device != null;

  /// Current endpoint-to-characteristic UUID mapping.
  Map<String, String> get endpointUuids => Map.unmodifiable(_endpointUuids);

  /// Scans for ESP provisioning devices matching [deviceNamePrefix].
  ///
  /// The scan runs for [duration] and returns de-duplicated devices by BLE id.
  /// Pass [serviceUuids] to add platform scan filters.
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

  /// Connects to [device], or scans and connects to the first matching device.
  ///
  /// After the BLE connection is established this discovers the provisioning
  /// service, derives endpoint UUIDs, and validates that required
  /// characteristics exist.
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
      _listenForDisconnect(target.id);
      await _requestMtu(target.id);
      await _discoverProvisioningService();
      return target;
    } catch (_) {
      await _cleanupFailedConnection(target.id);
      rethrow;
    }
  }

  /// Disconnects from the current device and clears local connection state.
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

  /// Performs the security handshake on the prov-session endpoint.
  ///
  /// Call this after [connect] and before sending Wi-Fi scan or configuration
  /// commands. Throws [ProvisionerError] when the device response cannot be
  /// parsed or security verification fails.
  Future<void> establishSession() async {
    await _runExclusive(_establishSession);
  }

  Future<void> _establishSession() async {
    _ensureConnected();

    final setup0 = await security.setup0Request();
    _log('Security setup0 request: ${setup0.length} bytes');
    await _writeEndpoint(provSessionEndpoint, setup0);
    final setup0Response = await _readEndpointResponse(provSessionEndpoint);
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
      final setup1Response = await _readEndpointResponse(provSessionEndpoint);
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

  /// Requests the device to reset provisioning state.
  Future<void> ctrlReset() async {
    await _exchange(
      provCtrlEndpoint,
      commands.ctrlResetRequest(),
      'Reset provisioning state',
      commands.ctrlResetResponse,
    );
  }

  /// Requests the device to enter re-provisioning mode.
  Future<void> ctrlReprov() async {
    await _exchange(
      provCtrlEndpoint,
      commands.ctrlReprovRequest(),
      'Re-provision',
      commands.ctrlReprovResponse,
    );
  }

  /// Starts a Wi-Fi scan on the ESP device.
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

  /// Returns the number of Wi-Fi scan results currently available.
  Future<int> getScanStatus() async {
    final status = await getScanStatusDetails();
    return status.resultCount;
  }

  /// Reads Wi-Fi scan progress from the ESP device.
  Future<WiFiScanStatus> getScanStatusDetails() async {
    return _exchange(
      provScanEndpoint,
      commands.scanStatusRequest(),
      'Get scan status',
      commands.scanStatusResponse,
    );
  }

  /// Reads Wi-Fi scan results from [startIndex] up to [count] entries.
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

  /// Runs a blocking Wi-Fi scan and returns available networks.
  ///
  /// Non-blocking scans are not implemented and throw [ProvisionerError].
  /// Results are fetched in small pages to avoid large BLE read responses.
  Future<List<WiFiNetwork>> scan([
    WiFiScanOptions options = const WiFiScanOptions(),
  ]) async {
    return scanPaged(options: options);
  }

  /// Runs a blocking Wi-Fi scan with configurable polling and result paging.
  ///
  /// Use [pageSize] to keep each BLE scan-result response small on devices or
  /// platforms that time out when many access points are returned at once.
  Future<List<WiFiNetwork>> scanPaged({
    WiFiScanOptions options = const WiFiScanOptions(),
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(seconds: 1),
    int pageSize = 4,
  }) async {
    if (pageSize <= 0) {
      throw ArgumentError.value(
        pageSize,
        'pageSize',
        'Must be greater than 0.',
      );
    }
    if (!options.blocking) {
      throw const ProvisionerError(
        'Non-blocking Wi-Fi scan is not implemented.',
      );
    }
    await startScan(options);
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await getScanStatusDetails();
      if (status.scanFinished) {
        if (status.resultCount == 0) return const <WiFiNetwork>[];
        final networks = <WiFiNetwork>[];
        for (var start = 0; start < status.resultCount; start += pageSize) {
          final remaining = status.resultCount - start;
          final count = remaining < pageSize ? remaining : pageSize;
          final page = await getScanResults(startIndex: start, count: count);
          networks.addAll(page);
        }
        return networks;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw ProvisionerError(
      'Wi-Fi scan timed out after ${timeout.inMilliseconds}ms.',
    );
  }

  /// Reads the current Wi-Fi connection status from the device.
  Future<WiFiStatus> getWiFiStatus() async {
    return _exchange(
      provConfigEndpoint,
      commands.configGetStatusRequest(),
      'Get Wi-Fi status',
      commands.configGetStatusResponse,
    );
  }

  /// Sends Wi-Fi credentials to the device without applying them.
  Future<void> setWiFiConfig(WiFiConfig config) async {
    await _exchange(
      provConfigEndpoint,
      commands.configSetConfigRequest(config),
      'Set Wi-Fi config',
      commands.configSetConfigResponse,
    );
  }

  /// Instructs the device to apply the last Wi-Fi configuration sent.
  Future<void> applyWiFiConfig() async {
    await _exchange(
      provConfigEndpoint,
      commands.configApplyConfigRequest(),
      'Apply Wi-Fi config',
      commands.configApplyConfigResponse,
    );
  }

  /// Polls Wi-Fi status until connected, failed, or [timeout] elapses.
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

  /// Sends [config], applies it, and waits for the device to connect.
  Future<WiFiStatus> sendCredentials(
    WiFiConfig config, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await setWiFiConfig(config);
    await applyWiFiConfig();
    return waitForWiFiStatus(timeout: timeout);
  }

  /// Encrypts and writes raw [value] to a registered endpoint.
  ///
  /// Use this for application-defined protocomm endpoints after the security
  /// session has been established.
  Future<void> writeValueToEndpoint(
    String endpointName,
    Uint8List value,
  ) async {
    await _runExclusive(() async {
      final encrypted = await security.encrypt(value);
      await _writeEndpoint(endpointName, encrypted);
    });
  }

  /// Reads and decrypts a raw value from a registered endpoint.
  Future<Uint8List> readValueFromEndpoint(String endpointName) async {
    return _runExclusive(() async {
      final value = await _readEndpoint(endpointName);
      return security.decrypt(value);
    });
  }

  /// Registers or overrides an endpoint characteristic UUID by name.
  void registerEndpoint(String endpointName, String characteristicUuid) {
    _endpointUuids[endpointName] = characteristicUuid;
  }

  /// Registers an ESP-IDF custom endpoint by sequential [index].
  ///
  /// Index 0 maps to short UUID 0xff54, index 1 to 0xff55, and so on.
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

    final characteristics = service.characteristics.map((c) => c.uuid).toList();
    _discoveredCharacteristicUuids =
        characteristics.map(_normalizeUuid).toSet();
    _log('Provisioning characteristics: ${characteristics.join(', ')}');
    _validateDiscoveredEndpoints([provSessionEndpoint, provConfigEndpoint]);
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
      final hasRequired = [provSessionEndpoint, provConfigEndpoint].every(
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
    final encryptedResponse = await _readEndpointResponse(endpointName);
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
    return _runExclusive(() async {
      final response = await _sendEncrypted(endpointName, plainRequest);
      return _parseResponse(operation, response, () => parse(response));
    });
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
      timeout: responseTimeout,
    );
  }

  Future<Uint8List> _readEndpoint(String endpointName, {Duration? timeout}) {
    final endpoint = _endpoint(endpointName);
    _log('Read $endpointName ${endpoint.characteristicUuid}');
    return _transport.read(
      _requireDeviceId(),
      endpoint.serviceUuid,
      endpoint.characteristicUuid,
      timeout: timeout,
    );
  }

  Future<Uint8List> _readEndpointResponse(String endpointName) async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    final deadline = DateTime.now().add(responseTimeout);
    Object? lastError;
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;

      try {
        final value = await _readEndpoint(
          endpointName,
          timeout: _shorterDuration(remaining, const Duration(seconds: 1)),
        );
        if (value.isNotEmpty) {
          return value;
        }
        lastError = null;
      } catch (error) {
        lastError = error;
      }

      final delay = _shorterDuration(
        readRetryInterval,
        deadline.difference(DateTime.now()),
      );
      if (delay <= Duration.zero) break;
      await Future<void>.delayed(delay);
    }

    final suffix = lastError == null ? '' : ' Last read error: $lastError.';
    throw ProvisionerError(
      'Timed out waiting for response from endpoint "$endpointName" after '
      '${responseTimeout.inMilliseconds}ms.$suffix',
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
    _ensureDiscoveredEndpoint(endpointName, characteristicUuid);
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
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connected = false;
    _device = null;
    _resolvedServiceUuid = null;
    _discoveredCharacteristicUuids = null;
  }

  void _listenForDisconnect(String deviceId) {
    _connectionSubscription?.cancel();
    _connectionSubscription = _transport
        .connectionStream(deviceId)
        .listen(
          (isConnected) {
            if (isConnected || _device?.id != deviceId) return;
            _log('Device disconnected: $deviceId');
            _clearConnectionState();
          },
          onError: (Object error) {
            _log('Connection stream error for $deviceId: $error');
          },
        );
  }

  void _validateDiscoveredEndpoints(Iterable<String> endpointNames) {
    for (final endpointName in endpointNames) {
      final characteristicUuid = _endpointUuids[endpointName];
      if (characteristicUuid == null || characteristicUuid.isEmpty) {
        throw ProvisionerError('Required endpoint "$endpointName" is missing.');
      }
      _ensureDiscoveredEndpoint(endpointName, characteristicUuid);
    }
  }

  void _ensureDiscoveredEndpoint(
    String endpointName,
    String characteristicUuid,
  ) {
    final discoveredCharacteristicUuids = _discoveredCharacteristicUuids;
    if (discoveredCharacteristicUuids == null) return;
    final normalized = _normalizeUuid(characteristicUuid);
    if (discoveredCharacteristicUuids.contains(normalized)) return;
    throw ProvisionerError(
      'Endpoint "$endpointName" characteristic not found: $characteristicUuid.',
    );
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationTail = _operationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Duration _shorterDuration(Duration a, Duration b) => a <= b ? a : b;

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
