import 'esp_ble_transport.dart';

EspBleTransport createPlatformTransport(String serviceUuid) {
  return const UniversalBleTransport();
}
