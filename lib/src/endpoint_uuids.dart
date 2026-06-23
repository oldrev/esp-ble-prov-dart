import 'package:universal_ble/universal_ble.dart';

import 'esp_ble_provisioner.dart';

const String defaultEspProvisioningServiceUuid =
    '0000ffff-0000-1000-8000-00805f9b34fb';

const Map<String, int> defaultEspProvisioningEndpointIds = {
  provCtrlEndpoint: 0xff4f,
  provScanEndpoint: 0xff50,
  provSessionEndpoint: 0xff51,
  provConfigEndpoint: 0xff52,
  protoVerEndpoint: 0xff53,
};

const int firstEspProvisioningCustomEndpointId = 0xff54;

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

String deriveEspProvisioningCustomEndpointUuid(String serviceUuid, int index) {
  return deriveProtocommCharacteristicUuid(
    serviceUuid,
    espProvisioningCustomEndpointShortUuid(index),
  );
}
