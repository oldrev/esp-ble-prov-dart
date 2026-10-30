import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import 'ble/esp_ble_transport.dart';
import 'ble/platform_transport.dart'
    if (dart.library.js_interop) 'ble/platform_transport_web.dart';
import 'endpoint_uuids.dart';
import 'models.dart';
import 'prov/proto_commands.dart' as commands;
import 'provisioner_error.dart';
import 'provisioning_options.dart';
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
    ProvisioningTimeouts timeouts = const ProvisioningTimeouts(),
    Duration? responseDelay,
    Duration? responseTimeout,
    Duration? readRetryInterval,
    this.logPayloads = false,
    void Function(String message)? onLog,
  }) : security = security ?? const Security0(),
       responseDelay = responseDelay ?? timeouts.responseDelay,
       responseTimeout = responseTimeout ?? timeouts.responseTimeout,
       readRetryInterval = readRetryInterval ?? timeouts.readRetryInterval,
       _transport = transport ?? createPlatformTransport(serviceUuid),
       _onLog = onLog,
       _explicitEndpointNames = endpointUuids.keys.toSet(),
       _endpointUuids = {
         ...deriveEspProvisioningEndpointUuids(serviceUuid),
         ...endpointUuids,
       },
       _endpointUuidSources = {
         for (final name
             in deriveEspProvisioningEndpointUuids(serviceUuid).keys)
           name: EndpointUuidSource.derived,
         for (final name in endpointUuids.keys)
           name: EndpointUuidSource.explicit,
       } {
    ProvisioningTimeouts(
      responseDelay: this.responseDelay,
      responseTimeout: this.responseTimeout,
      readRetryInterval: this.readRetryInterval,
    ).validate();
  }

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
  final Map<String, EndpointUuidSource> _endpointUuidSources;
  String? _resolvedServiceUuid;
  Set<String>? _discoveredCharacteristicUuids;
  StreamSubscription<bool>? _connectionSubscription;
  Future<void> _operationTail = Future<void>.value();
  int _queuedOperationCount = 0;
  int _connectionGeneration = 0;
  int? _activeConnectionGeneration;
  bool _disposed = false;

  EspBleDevice? _device;
  bool _connected = false;

  /// Currently connected device, or `null` when disconnected.
  EspBleDevice? get device => _device;

  /// Whether this provisioner currently has an active BLE connection.
  bool get isConnected => _connected && _device != null;

  /// Current endpoint-to-characteristic UUID mapping.
  Map<String, String> get endpointUuids => Map.unmodifiable(_endpointUuids);

  /// How each current endpoint UUID was resolved.
  Map<String, EndpointUuidSource> get endpointUuidSources =>
      Map.unmodifiable(_endpointUuidSources);

  /// Whether this platform uses a user-facing chooser instead of background
  /// BLE discovery. This is `true` for Web Bluetooth.
  bool get usesDeviceChooser =>
      kIsWeb || _transport is BleDeviceChooserTransport;

  /// Whether the active transport can read endpoint names from GATT
  /// descriptors. The built-in Web transport supports this; universal_ble
  /// 1.x does not expose descriptor values on native platforms.
  bool get supportsDescriptorEndpointDiscovery =>
      _transport is BleEndpointMappingTransport;

  /// Scans for ESP provisioning devices matching [deviceNamePrefix].
  ///
  /// The scan runs for [duration] and returns de-duplicated devices by BLE id.
  /// Pass [serviceUuids] to add platform scan filters. On chooser-based
  /// platforms such as Web Bluetooth, this opens the browser device picker and
  /// returns zero or one authorized device; it is not a background scan.
  Future<List<EspBleDevice>> scanDevices({
    Duration duration = const Duration(seconds: 8),
    List<String>? serviceUuids,
    ProvisioningCancellationToken? cancellationToken,
  }) {
    _ensureNotDisposed();
    if (duration <= Duration.zero) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Must be greater than 0.',
      );
    }
    if (usesDeviceChooser) {
      return authorizeDevice(
        serviceUuids: serviceUuids,
        cancellationToken: cancellationToken,
      ).then((device) => <EspBleDevice>[device]);
    }
    return _enqueue(
      () => _scanDevices(
        duration: duration,
        serviceUuids: serviceUuids,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<List<EspBleDevice>> _scanDevices({
    required Duration duration,
    List<String>? serviceUuids,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled('scanDevices');
    final devices = <String, EspBleDevice>{};
    final subscription = _transport.scanStream.listen((device) {
      final name = device.name ?? device.rawName;
      if (name == null || !name.startsWith(deviceNamePrefix)) return;
      devices[device.deviceId] = EspBleDevice(id: device.deviceId, name: name);
    });

    try {
      if (!usesDeviceChooser) {
        await _transport.requestPermissions(
          withAndroidFineLocation: requestAndroidFineLocation,
        );
      }
      await _transport.startScan(
        scanFilter: ScanFilter(
          withNamePrefix: [deviceNamePrefix],
          withServices: serviceUuids ?? const [],
        ),
        platformConfig:
            kIsWeb
                ? PlatformConfig(
                  web: WebOptions(optionalServices: [serviceUuid]),
                )
                : null,
      );
      // Web Bluetooth's requestDevice() already waits for a user selection and
      // emits exactly one device; it is not a timed discovery scan.
      if (!usesDeviceChooser) {
        await _delay(duration, cancellationToken, 'scanDevices');
      }
    } finally {
      try {
        await _transport.stopScan();
      } finally {
        await subscription.cancel();
      }
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
    ProvisioningCancellationToken? cancellationToken,
  }) {
    _ensureNotDisposed();
    if (isConnected) {
      throw const ProvisionerError('Already connected. Disconnect first.');
    }
    if (usesDeviceChooser && device == null) {
      throw const ProvisionerError(
        'Web Bluetooth cannot scan in the background. Call authorizeDevice() '
        'from a user gesture, then pass the returned device to connect().',
      );
    }
    final generation = ++_connectionGeneration;
    security.reset();
    return _enqueue(
      () => _connect(
        device: device,
        scanDuration: scanDuration,
        connectionTimeout: connectionTimeout,
        generation: generation,
        cancellationToken: cancellationToken,
      ),
    );
  }

  /// Opens the platform device chooser and returns the device authorized by the
  /// user. Web Bluetooth requires this call to originate from a user gesture.
  ///
  /// Native BLE platforms support background discovery through [scanDevices]
  /// and therefore reject this chooser-specific API.
  Future<EspBleDevice> authorizeDevice({
    List<String>? serviceUuids,
    ProvisioningCancellationToken? cancellationToken,
  }) {
    _ensureNotDisposed();
    if (!usesDeviceChooser) {
      throw const ProvisionerError(
        'authorizeDevice() is only available on chooser-based platforms. '
        'Use scanDevices() on this platform.',
        code: ProvisionerErrorCode.unsupported,
      );
    }
    if (_queuedOperationCount != 0) {
      throw const ProvisionerError(
        'The Web Bluetooth device chooser must be opened while the provisioner '
        'is idle.',
      );
    }
    return _runImmediate(
      () => _authorizeDevice(
        serviceUuids: serviceUuids,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<EspBleDevice> _authorizeDevice({
    List<String>? serviceUuids,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    final devices = await _scanDevices(
      duration: const Duration(milliseconds: 1),
      serviceUuids: serviceUuids,
      cancellationToken: cancellationToken,
    );
    if (devices.isEmpty) {
      throw const ProvisionerError('No BLE device was authorized.');
    }
    return devices.first;
  }

  Future<EspBleDevice> _connect({
    EspBleDevice? device,
    required Duration scanDuration,
    required Duration connectionTimeout,
    required int generation,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    _ensureNotDisposed();
    cancellationToken?.throwIfCancelled('connect');
    _ensureConnectionGeneration(generation);
    final target =
        device ??
        await _findFirstDevice(
          scanDuration,
          useInternalScan: true,
          cancellationToken: cancellationToken,
        );
    _ensureConnectionGeneration(generation);
    cancellationToken?.throwIfCancelled('connect');
    await _transport.stopScan();
    try {
      await _transport.connect(target.id, timeout: connectionTimeout);
      cancellationToken?.throwIfCancelled('connect');
      _ensureConnectionGeneration(generation);
      _device = target;
      _connected = true;
      _listenForDisconnect(target.id);
      await _requestMtu(target.id);
      _ensureConnectionGeneration(generation);
      await _discoverProvisioningService();
      _ensureConnectionGeneration(generation);
      return target;
    } catch (_) {
      await _cleanupFailedConnection(target.id);
      rethrow;
    }
  }

  /// Disconnects from the current device and clears local connection state.
  Future<void> disconnect({Duration? timeout}) {
    if (_disposed) return Future<void>.value();
    // Invalidate queued and in-flight protocol work immediately. The physical
    // disconnect remains serialized behind the currently executing BLE call.
    security.invalidate();
    _connectionGeneration++;
    return _enqueue(() => _disconnect(timeout: timeout));
  }

  Future<void> _disconnect({Duration? timeout}) async {
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

  /// Releases the connection, subscriptions, queued-operation ownership, and
  /// transport resources. Calling this method more than once is safe.
  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    security.invalidate();
    _connectionGeneration++;
    return _enqueue(() async {
      if (_disposed) return;
      await _disconnect();
      _disposed = true;
      _connectionGeneration++;
      final transport = _transport;
      if (transport is DisposableEspBleTransport) {
        await (transport as DisposableEspBleTransport).dispose();
      }
    });
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
    try {
      final setup0 = await security.setup0Request();
      _log('Security setup0 request: ${setup0.length} bytes');
      await _writeEndpoint(provSessionEndpoint, setup0);
      final setup0Response = await _readEndpointResponse(provSessionEndpoint);
      _log('Security setup0 response: ${setup0Response.length} bytes');
      await security.setup0Response(setup0Response);

      final setup1 = await security.setup1Request();
      if (setup1 != null) {
        _log('Security setup1 request: ${setup1.length} bytes');
        await _writeEndpoint(provSessionEndpoint, setup1);
        final setup1Response = await _readEndpointResponse(provSessionEndpoint);
        _log('Security setup1 response: ${setup1Response.length} bytes');
        await security.setup1Response(setup1Response);
      }
    } catch (error) {
      security.invalidate(error);
      if (error is ProvisionerError &&
          error.code != ProvisionerErrorCode.unknown) {
        rethrow;
      }
      throw ProvisionerError(
        'Security session establishment failed: $error.',
        code: ProvisionerErrorCode.securityFailed,
        operation: 'establishSession',
        cause: error,
      );
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
  Future<List<WiFiNetwork>> scan({
    WiFiScanOptions options = const WiFiScanOptions(),
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(seconds: 1),
    int pageSize = 4,
    ProvisioningCancellationToken? cancellationToken,
  }) {
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
    _validatePolling(timeout, pollInterval, 'scan');
    return _runExclusive(
      () => _scanUnlocked(
        options: options,
        timeout: timeout,
        pollInterval: pollInterval,
        pageSize: pageSize,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<List<WiFiNetwork>> _scanUnlocked({
    required WiFiScanOptions options,
    required Duration timeout,
    required Duration pollInterval,
    required int pageSize,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled('scan');
    await _exchangeUnlocked(
      provScanEndpoint,
      commands.scanStartRequest(options),
      'Start Wi-Fi scan',
      commands.scanStartResponse,
    );
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < timeout) {
      cancellationToken?.throwIfCancelled('scan');
      final status = await _exchangeUnlocked(
        provScanEndpoint,
        commands.scanStatusRequest(),
        'Get scan status',
        commands.scanStatusResponse,
      );
      if (status.scanFinished) {
        if (status.resultCount == 0) return const <WiFiNetwork>[];
        final networks = <WiFiNetwork>[];
        for (var start = 0; start < status.resultCount; start += pageSize) {
          final remaining = status.resultCount - start;
          final count = remaining < pageSize ? remaining : pageSize;
          final page = await _exchangeUnlocked(
            provScanEndpoint,
            commands.scanResultRequest(startIndex: start, count: count),
            'Get scan results',
            commands.scanResultResponse,
          );
          networks.addAll(page);
        }
        return networks;
      }
      await _delay(pollInterval, cancellationToken, 'scan');
    }
    throw ProvisionerError(
      'Wi-Fi scan timed out after ${timeout.inMilliseconds}ms.',
      code: ProvisionerErrorCode.timeout,
      operation: 'scan',
    );
  }

  /// Runs a blocking Wi-Fi scan with configurable polling and result paging.
  ///
  /// Use [pageSize] to keep each BLE scan-result response small on devices or
  /// platforms that time out when many access points are returned at once.
  @Deprecated('Use scan() with named parameters instead.')
  Future<List<WiFiNetwork>> scanPaged({
    WiFiScanOptions options = const WiFiScanOptions(),
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(seconds: 1),
    int pageSize = 4,
  }) {
    return scan(
      options: options,
      timeout: timeout,
      pollInterval: pollInterval,
      pageSize: pageSize,
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
    ProvisioningCancellationToken? cancellationToken,
  }) {
    _validatePolling(timeout, pollInterval, 'waitForWiFiStatus');
    return _runExclusive(
      () => _waitForWiFiStatusUnlocked(
        timeout: timeout,
        pollInterval: pollInterval,
        cancellationToken: cancellationToken,
      ),
    );
  }

  Future<WiFiStatus> _waitForWiFiStatusUnlocked({
    required Duration timeout,
    required Duration pollInterval,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    final elapsed = Stopwatch()..start();
    while (elapsed.elapsed < timeout) {
      cancellationToken?.throwIfCancelled('waitForWiFiStatus');
      final status = await _exchangeUnlocked(
        provConfigEndpoint,
        commands.configGetStatusRequest(),
        'Get Wi-Fi status',
        commands.configGetStatusResponse,
      );
      if (status.state == WiFiStationState.connected) return status;
      if (status.state == WiFiStationState.connectionFailed ||
          status.attemptsRemaining == 0) {
        throw ProvisionerError(
          'Wi-Fi connection failed: ${status.failReason?.name ?? 'no attempts remaining'}',
          code: ProvisionerErrorCode.wifiConnectionFailed,
          operation: 'waitForWiFiStatus',
        );
      }
      await _delay(pollInterval, cancellationToken, 'waitForWiFiStatus');
    }
    throw ProvisionerError(
      'Wi-Fi connection timed out after ${timeout.inMilliseconds}ms.',
      code: ProvisionerErrorCode.timeout,
      operation: 'waitForWiFiStatus',
    );
  }

  /// Sends [config], applies it, and waits for the device to connect.
  Future<WiFiStatus> sendCredentials(
    WiFiConfig config, {
    Duration timeout = const Duration(seconds: 60),
    ProvisioningCancellationToken? cancellationToken,
  }) {
    _validatePolling(timeout, const Duration(seconds: 1), 'sendCredentials');
    return _runExclusive(() async {
      cancellationToken?.throwIfCancelled('sendCredentials');
      await _exchangeUnlocked(
        provConfigEndpoint,
        commands.configSetConfigRequest(config),
        'Set Wi-Fi config',
        commands.configSetConfigResponse,
      );
      cancellationToken?.throwIfCancelled('sendCredentials');
      await _exchangeUnlocked(
        provConfigEndpoint,
        commands.configApplyConfigRequest(),
        'Apply Wi-Fi config',
        commands.configApplyConfigResponse,
      );
      return _waitForWiFiStatusUnlocked(
        timeout: timeout,
        pollInterval: const Duration(seconds: 1),
        cancellationToken: cancellationToken,
      );
    });
  }

  /// Encrypts and writes raw [value] to a registered endpoint.
  ///
  /// Use this for application-defined protocomm endpoints after the security
  /// session has been established.
  @Deprecated(
    'Use exchangeValueToEndpoint() for atomic request/response exchanges.',
  )
  Future<void> writeValueToEndpoint(
    String endpointName,
    Uint8List value,
  ) async {
    await _runExclusive(() async {
      try {
        final encrypted = await security.encrypt(value);
        await _writeEndpoint(endpointName, encrypted);
      } catch (error) {
        security.invalidate(error);
        rethrow;
      }
    });
  }

  /// Reads and decrypts a raw value from a registered endpoint.
  @Deprecated(
    'Use exchangeValueToEndpoint() for atomic request/response exchanges.',
  )
  Future<Uint8List> readValueFromEndpoint(String endpointName) async {
    return _runExclusive(() async {
      try {
        final value = await _readEndpoint(endpointName);
        return security.decrypt(value);
      } catch (error) {
        security.invalidate(error);
        rethrow;
      }
    });
  }

  /// Atomically writes [value] and reads its matching response on a custom
  /// endpoint, keeping stateful security streams aligned.
  Future<Uint8List> exchangeValueToEndpoint(
    String endpointName,
    Uint8List value,
  ) {
    return _runExclusive(() => _sendEncrypted(endpointName, value));
  }

  /// Registers or overrides an endpoint characteristic UUID by name.
  void registerEndpoint(String endpointName, String characteristicUuid) {
    if (endpointName.trim().isEmpty) {
      throw ArgumentError.value(
        endpointName,
        'endpointName',
        'Must not be empty.',
      );
    }
    _explicitEndpointNames.add(endpointName);
    _endpointUuids[endpointName] = characteristicUuid;
    _endpointUuidSources[endpointName] = EndpointUuidSource.explicit;
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

  Future<EspBleDevice> _findFirstDevice(
    Duration scanDuration, {
    bool useInternalScan = false,
    ProvisioningCancellationToken? cancellationToken,
  }) async {
    final devices =
        useInternalScan
            ? await _scanDevices(
              duration: scanDuration,
              cancellationToken: cancellationToken,
            )
            : await scanDevices(
              duration: scanDuration,
              cancellationToken: cancellationToken,
            );
    if (devices.isEmpty) {
      throw ProvisionerError(
        'No ESP provisioning device found with prefix $deviceNamePrefix.',
        code: ProvisionerErrorCode.deviceNotFound,
        operation: 'scanDevices',
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

    _endpointUuids.removeWhere(
      (name, _) => _endpointUuidSources[name] != EndpointUuidSource.explicit,
    );
    _endpointUuidSources.removeWhere(
      (_, source) => source != EndpointUuidSource.explicit,
    );
    final derived = deriveEspProvisioningEndpointUuids(service.uuid);
    for (final entry in derived.entries) {
      if (_explicitEndpointNames.contains(entry.key)) continue;
      _endpointUuids[entry.key] = entry.value;
      _endpointUuidSources[entry.key] = EndpointUuidSource.derived;
    }
    _log('Using provisioning service: ${service.uuid}');

    final characteristics = service.characteristics.map((c) => c.uuid).toList();
    _discoveredCharacteristicUuids =
        characteristics.map(_normalizeUuid).toSet();
    _log('Provisioning characteristics: ${characteristics.join(', ')}');
    await _applyDescriptorEndpointMappings(deviceId, service.uuid);
    _validateDiscoveredEndpoints([provSessionEndpoint, provConfigEndpoint]);
  }

  Future<void> _applyDescriptorEndpointMappings(
    String deviceId,
    String resolvedServiceUuid,
  ) async {
    final transport = _transport;
    if (transport is! BleEndpointMappingTransport) {
      _log(
        'Endpoint descriptors cannot be read by this transport; using UUID '
        'derivation fallback.',
      );
      return;
    }
    try {
      final mappings = await (transport as BleEndpointMappingTransport)
          .readEndpointMappings(deviceId, resolvedServiceUuid);
      final discovered = _discoveredCharacteristicUuids ?? const <String>{};
      var applied = 0;
      for (final entry in mappings.entries) {
        final endpointName = entry.key.trim();
        if (endpointName.isEmpty ||
            entry.value.isEmpty ||
            _explicitEndpointNames.contains(endpointName) ||
            !discovered.contains(_normalizeUuid(entry.value))) {
          continue;
        }
        _endpointUuids[endpointName] = entry.value;
        _endpointUuidSources[endpointName] = EndpointUuidSource.descriptor;
        applied++;
      }
      _log('Resolved $applied endpoint(s) from GATT descriptors.');
    } catch (error) {
      _log(
        'Endpoint descriptor resolution failed; using UUID derivation '
        'fallback: $error',
      );
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
    try {
      final encryptedRequest = await security.encrypt(plainRequest);
      _ensureActiveOperationCurrent();
      await _writeEndpoint(endpointName, encryptedRequest);
      _ensureActiveOperationCurrent();
      final encryptedResponse = await _readEndpointResponse(endpointName);
      _ensureActiveOperationCurrent();
      _logPayload(
        'Encrypted response $endpointName: '
        '${encryptedResponse.length} bytes ${_hexPreview(encryptedResponse)}',
      );
      if (_looksLikeProtoVersionResponse(encryptedResponse)) {
        throw ProvisionerError(
          'Endpoint "$endpointName" read proto-ver JSON. Check endpoint UUID '
          'mapping for the connected firmware.',
        );
      }
      final plainResponse = await security.decrypt(encryptedResponse);
      _logPayload(
        'Decrypted response $endpointName: '
        '${plainResponse.length} bytes ${_hexPreview(plainResponse)}',
      );
      return plainResponse;
    } catch (error) {
      security.invalidate(error);
      rethrow;
    }
  }

  Future<T> _exchange<T>(
    String endpointName,
    Uint8List plainRequest,
    String operation,
    T Function(Uint8List response) parse,
  ) async {
    return _runExclusive(
      () => _exchangeUnlocked(endpointName, plainRequest, operation, parse),
    );
  }

  Future<T> _exchangeUnlocked<T>(
    String endpointName,
    Uint8List plainRequest,
    String operation,
    T Function(Uint8List response) parse,
  ) async {
    final response = await _sendEncrypted(endpointName, plainRequest);
    return _parseResponse(operation, () => parse(response));
  }

  T _parseResponse<T>(String operation, T Function() parse) {
    try {
      return parse();
    } catch (error) {
      if (error is ProvisionerError &&
          error.code != ProvisionerErrorCode.unknown) {
        rethrow;
      }
      throw ProvisionerError(
        '$operation response parse failed: $error.',
        code: ProvisionerErrorCode.protocolViolation,
        operation: operation,
        cause: error,
      );
    }
  }

  Future<void> _writeEndpoint(String endpointName, Uint8List value) async {
    _ensureActiveOperationCurrent();
    final endpoint = _endpoint(endpointName);
    _log(
      'Write $endpointName ${endpoint.characteristicUuid}: '
      '${value.length} bytes',
    );
    _logPayload('Write payload $endpointName: ${_hexPreview(value)}');
    await _transport.write(
      _requireDeviceId(),
      endpoint.serviceUuid,
      endpoint.characteristicUuid,
      value,
      timeout: responseTimeout,
    );
    _ensureActiveOperationCurrent();
  }

  Future<Uint8List> _readEndpoint(
    String endpointName, {
    Duration? timeout,
  }) async {
    _ensureActiveOperationCurrent();
    final endpoint = _endpoint(endpointName);
    _log('Read $endpointName ${endpoint.characteristicUuid}');
    final value = await _transport.read(
      _requireDeviceId(),
      endpoint.serviceUuid,
      endpoint.characteristicUuid,
      timeout: timeout,
    );
    _ensureActiveOperationCurrent();
    return value;
  }

  Future<Uint8List> _readEndpointResponse(String endpointName) async {
    if (responseDelay > Duration.zero) {
      await Future<void>.delayed(responseDelay);
    }

    final elapsed = Stopwatch()..start();
    Object? lastError;
    while (true) {
      final remaining = responseTimeout - elapsed.elapsed;
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
        if (error is ProvisionerError &&
            (error.code == ProvisionerErrorCode.connectionLost ||
                error.code == ProvisionerErrorCode.cancelled ||
                error.code == ProvisionerErrorCode.disposed ||
                error.code == ProvisionerErrorCode.sessionInvalidated)) {
          rethrow;
        }
        lastError = error;
      }

      final delay = _shorterDuration(
        readRetryInterval,
        responseTimeout - elapsed.elapsed,
      );
      if (delay <= Duration.zero) break;
      await Future<void>.delayed(delay);
    }

    final suffix = lastError == null ? '' : ' Last read error: $lastError.';
    throw ProvisionerError(
      'Timed out waiting for response from endpoint "$endpointName" after '
      '${responseTimeout.inMilliseconds}ms.$suffix',
      code: ProvisionerErrorCode.timeout,
      operation: 'readEndpointResponse',
      endpoint: endpointName,
      cause: lastError,
      isRetryable: security is Security0,
    );
  }

  BleEndpoint _endpoint(String endpointName) {
    final characteristicUuid = _endpointUuids[endpointName];
    if (characteristicUuid == null || characteristicUuid.isEmpty) {
      throw ProvisionerError(
        'Endpoint "$endpointName" is not registered. Pass endpointUuids when '
        'creating EspBleProvisioner or call registerEndpoint().',
        code: ProvisionerErrorCode.endpointNotFound,
        endpoint: endpointName,
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
        code: ProvisionerErrorCode.connectionLost,
      );
    }
    return deviceId;
  }

  void _ensureConnected() => _requireDeviceId();

  void _clearConnectionState() {
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    security.invalidate();
    _connectionGeneration++;
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
      code: ProvisionerErrorCode.endpointNotFound,
      endpoint: endpointName,
    );
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    _ensureNotDisposed();
    final generation = _connectionGeneration;
    return _enqueue(() async {
      if (generation != _connectionGeneration) {
        throw const ProvisionerError(
          'The operation belongs to an expired BLE connection.',
          code: ProvisionerErrorCode.connectionLost,
        );
      }
      _activeConnectionGeneration = generation;
      try {
        final result = await action();
        if (generation != _connectionGeneration) {
          throw const ProvisionerError(
            'The BLE connection changed while the operation was running.',
            code: ProvisionerErrorCode.connectionLost,
          );
        }
        return result;
      } finally {
        _activeConnectionGeneration = null;
      }
    });
  }

  void _ensureActiveOperationCurrent() {
    final activeGeneration = _activeConnectionGeneration;
    if (activeGeneration != null && activeGeneration != _connectionGeneration) {
      throw const ProvisionerError(
        'The BLE connection changed while the operation was running.',
        code: ProvisionerErrorCode.connectionLost,
      );
    }
  }

  void _ensureConnectionGeneration(int generation) {
    if (generation != _connectionGeneration) {
      throw const ProvisionerError(
        'The BLE connection attempt was superseded or cancelled.',
        code: ProvisionerErrorCode.cancelled,
      );
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    _queuedOperationCount++;
    final completer = Completer<T>();
    _operationTail = _operationTail.catchError((_) {}).then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(_normalizeError(error, stackTrace), stackTrace);
      } finally {
        _queuedOperationCount--;
      }
    });
    return completer.future;
  }

  Future<T> _runImmediate<T>(Future<T> Function() action) {
    _queuedOperationCount++;
    late final Future<T> future;
    try {
      // Invoke synchronously so Web Bluetooth requestDevice() remains inside
      // the originating user-activation task.
      future = action().onError((error, stackTrace) {
        throw _normalizeError(
          error ?? StateError('Unknown asynchronous provisioning failure.'),
          stackTrace,
        );
      });
    } catch (_) {
      _queuedOperationCount--;
      rethrow;
    }
    _operationTail = future
        .then<void>((_) {})
        .catchError((_) {})
        .whenComplete(() => _queuedOperationCount--);
    return future;
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const ProvisionerError(
        'EspBleProvisioner has been disposed.',
        code: ProvisionerErrorCode.disposed,
      );
    }
  }

  ProvisionerError _normalizeError(Object error, StackTrace stackTrace) {
    if (error is ProvisionerError) return error;
    final description = error.toString();
    if (description.contains('NotFoundError')) {
      return ProvisionerError(
        'Bluetooth device selection was cancelled.',
        code: ProvisionerErrorCode.cancelled,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    if (description.contains('NotAllowedError') ||
        description.contains('SecurityError')) {
      return ProvisionerError(
        'Bluetooth access was denied or requires a secure user gesture.',
        code: ProvisionerErrorCode.permissionDenied,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    if (description.contains('NotSupportedError') ||
        description.contains('NotImplemented')) {
      return ProvisionerError(
        'Bluetooth is not supported by this platform or browser.',
        code: ProvisionerErrorCode.unsupported,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    if (error is TimeoutException) {
      return ProvisionerError(
        'Provisioning transport timed out: $error',
        code: ProvisionerErrorCode.timeout,
        cause: error,
        causeStackTrace: stackTrace,
        isRetryable: security is Security0,
      );
    }
    if (error is UnsupportedError) {
      return ProvisionerError(
        error.message?.toString() ?? 'Operation is not supported.',
        code: ProvisionerErrorCode.unsupported,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
    return ProvisionerError(
      'Provisioning operation failed: $error',
      cause: error,
      causeStackTrace: stackTrace,
    );
  }

  Duration _shorterDuration(Duration a, Duration b) => a <= b ? a : b;

  void _validatePolling(
    Duration timeout,
    Duration pollInterval,
    String operation,
  ) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', '$operation timeout > 0');
    }
    if (pollInterval <= Duration.zero) {
      throw ArgumentError.value(
        pollInterval,
        'pollInterval',
        '$operation pollInterval > 0',
      );
    }
  }

  Future<void> _delay(
    Duration duration,
    ProvisioningCancellationToken? token,
    String operation,
  ) async {
    token?.throwIfCancelled(operation);
    if (token == null) {
      await Future<void>.delayed(duration);
      return;
    }
    await Future.any<void>([
      Future<void>.delayed(duration),
      token.whenCancelled,
    ]);
    token.throwIfCancelled(operation);
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
}
