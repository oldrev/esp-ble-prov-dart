import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'esp_ble_transport.dart';

@JS('navigator.bluetooth')
external _Bluetooth? get _bluetooth;

extension type _Bluetooth(JSObject _) implements JSObject {
  external JSPromise<_BluetoothDevice> requestDevice(JSObject options);
}

extension type _BluetoothDevice(JSObject _) implements JSObject {
  external String get id;
  external String? get name;
  external _BluetoothRemoteGATTServer? get gatt;
  external void addEventListener(String type, JSFunction listener);
  external void removeEventListener(String type, JSFunction listener);
}

extension type _BluetoothRemoteGATTServer(JSObject _) implements JSObject {
  external bool get connected;
  external JSPromise<_BluetoothRemoteGATTServer> connect();
  external void disconnect();
  external JSPromise<_BluetoothRemoteGATTService> getPrimaryService(
    String serviceUuid,
  );
}

extension type _BluetoothRemoteGATTService(JSObject _) implements JSObject {
  external String get uuid;
  external JSPromise<_BluetoothRemoteGATTCharacteristic> getCharacteristic(
    String characteristicUuid,
  );
  external JSPromise<JSArray<_BluetoothRemoteGATTCharacteristic>>
  getCharacteristics();
}

extension type _BluetoothRemoteGATTCharacteristic(JSObject _)
    implements JSObject {
  external String get uuid;
  external JSPromise<JSDataView> readValue();
  external JSPromise<JSAny?> writeValue(JSArrayBuffer value);
  external JSPromise<JSAny?> writeValueWithResponse(JSArrayBuffer value);
  external JSPromise<JSAny?> writeValueWithoutResponse(JSArrayBuffer value);
  external JSPromise<JSArray<_BluetoothRemoteGATTDescriptor>> getDescriptors();
}

extension type _BluetoothRemoteGATTDescriptor(JSObject _) implements JSObject {
  external String get uuid;
  external JSPromise<JSDataView> readValue();
}

class WebEspBleTransport
    implements
        EspBleTransport,
        DisposableEspBleTransport,
        BleDeviceChooserTransport,
        BleEndpointMappingTransport {
  WebEspBleTransport({required this.serviceUuid});

  final String serviceUuid;
  final _scanController = StreamController<BleDevice>.broadcast();
  final Map<String, _BluetoothDevice> _devices = {};
  final Map<String, _BluetoothRemoteGATTService> _services = {};
  final Map<String, _BluetoothRemoteGATTCharacteristic> _characteristics = {};
  final Map<String, StreamController<bool>> _connectionControllers = {};
  final Map<String, JSFunction> _disconnectListeners = {};
  bool _disposed = false;

  @override
  Stream<BleDevice> get scanStream => _scanController.stream;

  @override
  Stream<bool> connectionStream(String deviceId) {
    return _connectionController(deviceId).stream;
  }

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {
    // Web Bluetooth asks for device access from startScan/requestDevice.
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    _ensureNotDisposed();
    final bluetooth = _bluetooth;
    if (bluetooth == null) {
      throw UniversalBleException(
        code: UniversalBleErrorCode.notImplemented,
        message: 'Web Bluetooth is not available in this browser',
      );
    }

    final optionalServices = <String>{
      serviceUuid,
      ...?platformConfig?.web?.optionalServices,
      ...?scanFilter?.withServices,
    }.toList(growable: false);
    final options = _requestOptions(
      namePrefixes: scanFilter?.withNamePrefix ?? const <String>[],
      optionalServices: optionalServices,
    );

    final device = await bluetooth.requestDevice(options).toDart;
    _devices[device.id] = device;
    _registerDisconnectListener(device);
    _scanController.add(BleDevice(deviceId: device.id, name: device.name));
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    _ensureNotDisposed();
    final device = _requireDevice(deviceId);
    final gatt = device.gatt;
    if (gatt == null) {
      throw StateError('Web Bluetooth GATT server is not available.');
    }
    final server = await gatt.connect().toDart.timeout(
      timeout ?? const Duration(seconds: 10),
    );
    if (!server.connected) {
      throw StateError('Web Bluetooth GATT server is not connected.');
    }
    final service = await server.getPrimaryService(serviceUuid).toDart;
    _services[deviceId] = service;
    _connectionController(deviceId).add(true);
  }

  @override
  Future<void> disconnect(String deviceId, {Duration? timeout}) async {
    final controller = _connectionControllers[deviceId];
    final device = _devices[deviceId];
    _removeDisconnectListener(deviceId);
    device?.gatt?.disconnect();
    _releaseDeviceCaches(deviceId);
    if (controller != null && !controller.isClosed) controller.add(false);
    await controller?.close();
    _connectionControllers.remove(deviceId);
  }

  @override
  Future<int> requestMtu(
    String deviceId,
    int expectedMtu, {
    Duration? timeout,
  }) async {
    throw UniversalBleException(
      code: UniversalBleErrorCode.notImplemented,
      message: 'requestMtu is not implemented on Web platform',
    );
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId, {
    bool withDescriptors = false,
  }) async {
    final service = await _getService(deviceId);
    final characteristics = <BleCharacteristic>[];
    final webCharacteristics =
        (await service.getCharacteristics().toDart).toDart;
    for (final characteristic in webCharacteristics) {
      final descriptors = <BleDescriptor>[];
      if (withDescriptors) {
        try {
          final webDescriptors =
              (await characteristic.getDescriptors().toDart).toDart;
          descriptors.addAll(
            webDescriptors.map((descriptor) => BleDescriptor(descriptor.uuid)),
          );
        } catch (_) {
          // Descriptor discovery is optional. Endpoint resolution falls back
          // to UUID derivation when the browser/device does not expose it.
        }
      }
      characteristics.add(
        BleCharacteristic(characteristic.uuid, const [], descriptors),
      );
    }
    return [BleService(service.uuid, characteristics)];
  }

  @override
  Future<Map<String, String>> readEndpointMappings(
    String deviceId,
    String requestedServiceUuid,
  ) async {
    if (!BleUuidParser.compareStrings(requestedServiceUuid, serviceUuid)) {
      return const {};
    }
    final service = await _getService(deviceId);
    final characteristics = (await service.getCharacteristics().toDart).toDart;
    final mappings = <String, String>{};
    for (final characteristic in characteristics) {
      try {
        final descriptors =
            (await characteristic.getDescriptors().toDart).toDart;
        for (final descriptor in descriptors) {
          if (!BleUuidParser.compareStrings(
            descriptor.uuid,
            '00002901-0000-1000-8000-00805f9b34fb',
          )) {
            continue;
          }
          final data = (await descriptor.readValue().toDart).toDart;
          final bytes = Uint8List.view(
            data.buffer,
            data.offsetInBytes,
            data.lengthInBytes,
          );
          final endpointName =
              utf8.decode(bytes).replaceAll('\u0000', '').trim();
          if (endpointName.isNotEmpty) {
            mappings[endpointName] = characteristic.uuid;
          }
        }
      } catch (_) {
        // Ignore one inaccessible/malformed descriptor and continue resolving
        // the remaining characteristics.
      }
    }
    return mappings;
  }

  @override
  Future<Uint8List> read(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    Duration? timeout,
  }) async {
    final characteristic = await _getCharacteristic(
      deviceId,
      serviceUuid,
      characteristicUuid,
    );
    final future = characteristic.readValue().toDart;
    final data = await (timeout == null ? future : future.timeout(timeout));
    final bytes = data.toDart;
    return Uint8List.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
  }

  @override
  Future<void> write(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List value, {
    bool withoutResponse = false,
    Duration? timeout,
  }) async {
    final characteristic = await _getCharacteristic(
      deviceId,
      serviceUuid,
      characteristicUuid,
    );
    // A TypedData view keeps its original backing buffer. Copy the visible
    // range so Web Bluetooth never receives bytes outside this Uint8List.
    final buffer = compactBleWriteValue(value).buffer.toJS;
    final future =
        withoutResponse
            ? characteristic.writeValueWithoutResponse(buffer).toDart
            : characteristic.writeValueWithResponse(buffer).toDart;
    await (timeout == null ? future : future.timeout(timeout));
  }

  _BluetoothDevice _requireDevice(String deviceId) {
    final device = _devices[deviceId];
    if (device == null) throw StateError('Device $deviceId not found.');
    return device;
  }

  StreamController<bool> _connectionController(String deviceId) {
    return _connectionControllers.putIfAbsent(
      deviceId,
      () => StreamController<bool>.broadcast(),
    );
  }

  void _registerDisconnectListener(_BluetoothDevice device) {
    if (_disconnectListeners.containsKey(device.id)) return;
    late final JSFunction listener;
    listener =
        ((JSAny? _) {
          device.removeEventListener('gattserverdisconnected', listener);
          final controller = _connectionControllers[device.id];
          if (controller != null && !controller.isClosed) {
            controller.add(false);
            unawaited(controller.close());
          }
          _connectionControllers.remove(device.id);
          _disconnectListeners.remove(device.id);
          _releaseDeviceCaches(device.id);
        }).toJS;
    _disconnectListeners[device.id] = listener;
    device.addEventListener('gattserverdisconnected', listener);
  }

  void _removeDisconnectListener(String deviceId) {
    final listener = _disconnectListeners.remove(deviceId);
    final device = _devices[deviceId];
    if (listener != null && device != null) {
      device.removeEventListener('gattserverdisconnected', listener);
    }
  }

  void _releaseDeviceCaches(String deviceId) {
    _services.remove(deviceId);
    _characteristics.removeWhere((key, _) => key.startsWith('$deviceId|'));
    _devices.remove(deviceId);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final deviceId in _devices.keys.toList(growable: false)) {
      _removeDisconnectListener(deviceId);
      _devices[deviceId]?.gatt?.disconnect();
      _releaseDeviceCaches(deviceId);
    }
    for (final controller in _connectionControllers.values) {
      await controller.close();
    }
    _connectionControllers.clear();
    await _scanController.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) throw StateError('WebEspBleTransport has been disposed.');
  }

  Future<_BluetoothRemoteGATTService> _getService(String deviceId) async {
    final cached = _services[deviceId];
    if (cached != null) return cached;
    final device = _requireDevice(deviceId);
    final gatt = device.gatt;
    if (gatt == null || !gatt.connected) {
      throw StateError('Web Bluetooth GATT server is not connected.');
    }
    final service = await gatt.getPrimaryService(serviceUuid).toDart;
    _services[deviceId] = service;
    return service;
  }

  Future<_BluetoothRemoteGATTCharacteristic> _getCharacteristic(
    String deviceId,
    String requestedServiceUuid,
    String characteristicUuid,
  ) async {
    if (!BleUuidParser.compareStrings(requestedServiceUuid, serviceUuid)) {
      throw StateError('Service $requestedServiceUuid is not available.');
    }
    final key = '$deviceId|$characteristicUuid';
    final cached = _characteristics[key];
    if (cached != null) return cached;
    final service = await _getService(deviceId);
    final characteristic =
        await service.getCharacteristic(characteristicUuid).toDart;
    _characteristics[key] = characteristic;
    return characteristic;
  }

  JSObject _requestOptions({
    required List<String> namePrefixes,
    required List<String> optionalServices,
  }) {
    final options = JSObject();
    options.setProperty(
      'optionalServices'.toJS,
      optionalServices
          .map((service) => service.toLowerCase().toJS)
          .toList()
          .toJS,
    );

    if (namePrefixes.isEmpty) {
      options.setProperty('acceptAllDevices'.toJS, true.toJS);
      return options;
    }

    final filters =
        namePrefixes
            .map((prefix) {
              final filter = JSObject();
              filter.setProperty('namePrefix'.toJS, prefix.toJS);
              return filter;
            })
            .toList()
            .toJS;
    options.setProperty('filters'.toJS, filters);
    return options;
  }
}
