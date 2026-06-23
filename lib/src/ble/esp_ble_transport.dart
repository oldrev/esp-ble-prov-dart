import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

class BleEndpoint {
  const BleEndpoint({
    required this.serviceUuid,
    required this.characteristicUuid,
  });

  final String serviceUuid;
  final String characteristicUuid;
}

abstract class EspBleTransport {
  Stream<BleDevice> get scanStream;

  Future<void> requestPermissions({bool withAndroidFineLocation = false});
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  });
  Future<void> stopScan();
  Future<void> connect(String deviceId, {Duration? timeout});
  Future<void> disconnect(String deviceId, {Duration? timeout});
  Future<int> requestMtu(String deviceId, int expectedMtu, {Duration? timeout});
  Future<List<BleService>> discoverServices(
    String deviceId, {
    bool withDescriptors = false,
  });
  Future<Uint8List> read(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    Duration? timeout,
  });
  Future<void> write(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List value, {
    bool withoutResponse = false,
    Duration? timeout,
  });
}

class UniversalBleTransport implements EspBleTransport {
  const UniversalBleTransport();

  @override
  Stream<BleDevice> get scanStream => UniversalBle.scanStream;

  @override
  Future<void> requestPermissions({bool withAndroidFineLocation = false}) {
    return UniversalBle.requestPermissions(
      withAndroidFineLocation: withAndroidFineLocation,
    );
  }

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) {
    return UniversalBle.startScan(
      scanFilter: scanFilter,
      platformConfig: platformConfig,
    );
  }

  @override
  Future<void> stopScan() => UniversalBle.stopScan();

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) {
    return UniversalBle.connect(deviceId, timeout: timeout);
  }

  @override
  Future<void> disconnect(String deviceId, {Duration? timeout}) {
    return UniversalBle.disconnect(deviceId, timeout: timeout);
  }

  @override
  Future<int> requestMtu(
    String deviceId,
    int expectedMtu, {
    Duration? timeout,
  }) {
    return UniversalBle.requestMtu(deviceId, expectedMtu, timeout: timeout);
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId, {
    bool withDescriptors = false,
  }) {
    return UniversalBle.discoverServices(
      deviceId,
      withDescriptors: withDescriptors,
    );
  }

  @override
  Future<Uint8List> read(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    Duration? timeout,
  }) {
    return UniversalBle.read(
      deviceId,
      serviceUuid,
      characteristicUuid,
      timeout: timeout,
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
  }) {
    return UniversalBle.write(
      deviceId,
      serviceUuid,
      characteristicUuid,
      value,
      withoutResponse: withoutResponse,
      timeout: timeout,
    );
  }
}
