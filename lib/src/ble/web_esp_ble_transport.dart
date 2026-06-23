import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart' as web_ble;
import 'package:universal_ble/universal_ble.dart';

import 'esp_ble_transport.dart';

class WebEspBleTransport implements EspBleTransport {
  WebEspBleTransport({required this.serviceUuid});

  final String serviceUuid;
  final _scanController = StreamController<BleDevice>.broadcast();
  static final Map<String, web_ble.BluetoothDevice> _devices = {};
  static final Map<String, web_ble.BluetoothService> _services = {};
  static final Map<String, web_ble.BluetoothCharacteristic> _characteristics = {};

  @override
  Stream<BleDevice> get scanStream => _scanController.stream;

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
    final prefixes = scanFilter?.withNamePrefix ?? const <String>[];
    final filters = prefixes.isEmpty
        ? <web_ble.RequestFilterBuilder>[]
        : prefixes
              .map((prefix) => web_ble.RequestFilterBuilder(namePrefix: prefix))
              .toList(growable: false);
    final optionalServices = <String>{
      serviceUuid,
      ...?platformConfig?.web?.optionalServices,
      ...?scanFilter?.withServices,
    }.toList(growable: false);

    final options = filters.isEmpty
        ? web_ble.RequestOptionsBuilder.acceptAllDevices(
            optionalServices: optionalServices,
            optionalManufacturerData:
                platformConfig?.web?.optionalManufacturerData,
          )
        : web_ble.RequestOptionsBuilder(
            filters,
            optionalServices: optionalServices,
            optionalManufacturerData:
                platformConfig?.web?.optionalManufacturerData,
          );

    final device = await web_ble.FlutterWebBluetooth.instance.requestDevice(
      options,
    );
    _devices[device.id] = device;
    _scanController.add(BleDevice(deviceId: device.id, name: device.name));
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    final device = _requireDevice(deviceId);
    await device.connect(timeout: timeout ?? const Duration(seconds: 10));
    final gatt = device.nativeDevice.gatt;
    if (gatt == null || !gatt.connected) {
      throw StateError('Web Bluetooth GATT server is not connected.');
    }
    final nativeService = await gatt.getPrimaryService(serviceUuid);
    _services[deviceId] = web_ble.BluetoothService(nativeService);
  }

  @override
  Future<void> disconnect(String deviceId, {Duration? timeout}) async {
    _devices[deviceId]?.disconnect();
    _services.remove(deviceId);
    _characteristics.removeWhere((key, _) => key.startsWith('$deviceId|'));
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
    for (final characteristic in await service.getCharacteristics()) {
      characteristics.add(
        BleCharacteristic(characteristic.uuid, const [], const []),
      );
    }
    return [BleService(service.uuid, characteristics)];
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
    final data = await characteristic.readValue(
      timeout: timeout ?? const Duration(seconds: 5),
    );
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
    if (withoutResponse) {
      await characteristic.writeValueWithoutResponse(value);
    } else {
      await characteristic.writeValueWithResponse(value);
    }
  }

  web_ble.BluetoothDevice _requireDevice(String deviceId) {
    final device = _devices[deviceId];
    if (device == null) throw StateError('Device $deviceId not found.');
    return device;
  }

  Future<web_ble.BluetoothService> _getService(String deviceId) async {
    final cached = _services[deviceId];
    if (cached != null) return cached;
    final device = _requireDevice(deviceId);
    final gatt = device.nativeDevice.gatt;
    if (gatt == null || !gatt.connected) {
      throw StateError('Web Bluetooth GATT server is not connected.');
    }
    final nativeService = await gatt.getPrimaryService(serviceUuid);
    final service = web_ble.BluetoothService(nativeService);
    _services[deviceId] = service;
    return service;
  }

  Future<web_ble.BluetoothCharacteristic> _getCharacteristic(
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
    final characteristic = await service.getCharacteristic(characteristicUuid);
    _characteristics[key] = characteristic;
    return characteristic;
  }
}
