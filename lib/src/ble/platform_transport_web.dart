import 'esp_ble_transport.dart';
import 'web_esp_ble_transport.dart';

EspBleTransport createPlatformTransport(String serviceUuid) {
  return WebEspBleTransport(serviceUuid: serviceUuid);
}
