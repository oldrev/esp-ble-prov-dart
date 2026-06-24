import 'package:universal_ble/universal_ble.dart';

import 'esp_ble_provisioner.dart';

/// Default ESP-IDF BLE provisioning service UUID.
const String kDefaultEspProvisioningServiceUuid =
    '1775244d-6b43-439b-877c-060f2d9bed07';

/// Default ESP-IDF protocomm endpoint names and their 16-bit characteristic
/// UUID fragments.
const Map<String, int> defaultEspProvisioningEndpointIds = {
  provCtrlEndpoint: 0xff4f,
  provScanEndpoint: 0xff50,
  provSessionEndpoint: 0xff51,
  provConfigEndpoint: 0xff52,
  protoVerEndpoint: 0xff53,
};

/// First 16-bit characteristic UUID fragment used by ESP-IDF custom endpoints.
const int firstEspProvisioningCustomEndpointId = 0xff54;

/// Derives all default ESP provisioning endpoint characteristic UUIDs from
/// [serviceUuid].
///
/// ESP-IDF embeds the endpoint short UUID into bytes 2 and 3 of the service
/// UUID. Pass [endpointIds] to derive a custom set of endpoint names.
Map<String, String> deriveEspProvisioningEndpointUuids(
  String serviceUuid, {
  Map<String, int> endpointIds = defaultEspProvisioningEndpointIds,
}) {
  return endpointIds.map(
    (endpoint, shortUuid) => MapEntry(
      endpoint,
      deriveProtocommCharacteristicUuid(serviceUuid, shortUuid),
    ),
  );
}

/// Derives a protocomm characteristic UUID from a service UUID and 16-bit
/// [shortUuid].
///
/// Throws [RangeError] when [shortUuid] is outside `0x0000..0xffff`.
String deriveProtocommCharacteristicUuid(String serviceUuid, int shortUuid) {
  if (shortUuid < 0 || shortUuid > 0xffff) {
    throw RangeError.range(shortUuid, 0, 0xffff, 'shortUuid');
  }

  final normalized = BleUuidParser.string(serviceUuid).replaceAll('-', '');
  final bytes = <int>[];
  for (var i = 0; i < normalized.length; i += 2) {
    bytes.add(int.parse(normalized.substring(i, i + 2), radix: 16));
  }

  bytes[2] = (shortUuid >> 8) & 0xff;
  bytes[3] = shortUuid & 0xff;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

/// Returns the 16-bit characteristic UUID fragment for a custom endpoint
/// [index].
///
/// ESP-IDF assigns custom provisioning endpoints sequentially starting at
/// `0xff54`. Throws [RangeError] when [index] is negative or would exceed the
/// 16-bit UUID range.
int espProvisioningCustomEndpointShortUuid(int index) {
  if (index < 0) {
    throw RangeError.range(index, 0, null, 'index');
  }
  final shortUuid = firstEspProvisioningCustomEndpointId + index;
  if (shortUuid > 0xffff) {
    throw RangeError.range(
      index,
      0,
      0xffff - firstEspProvisioningCustomEndpointId,
      'index',
    );
  }
  return shortUuid;
}

/// Derives the characteristic UUID for a custom ESP provisioning endpoint.
String deriveEspProvisioningCustomEndpointUuid(String serviceUuid, int index) {
  return deriveProtocommCharacteristicUuid(
    serviceUuid,
    espProvisioningCustomEndpointShortUuid(index),
  );
}
