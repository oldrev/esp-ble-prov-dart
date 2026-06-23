import 'dart:typed_data';

import '../models.dart';
import '../proto/protos.dart' as pb;
import '../provisioner_error.dart';

void _ensureStatus(pb.Status status, String operation) {
  if (status != pb.Status.Success) {
    throw ProvisionerError('$operation failed: ${status.name}');
  }
}

Uint8List ctrlResetRequest() {
  return Uint8List.fromList(
    pb.WiFiCtrlPayload(
      msg: pb.WiFiCtrlMsgType.TypeCmdCtrlReset,
      cmdCtrlReset: pb.CmdCtrlReset(),
    ).writeToBuffer(),
  );
}

void ctrlResetResponse(Uint8List response) {
  final payload = pb.WiFiCtrlPayload.fromBuffer(response);
  _ensureStatus(payload.status, 'Reset provisioning state');
}

Uint8List ctrlReprovRequest() {
  return Uint8List.fromList(
    pb.WiFiCtrlPayload(
      msg: pb.WiFiCtrlMsgType.TypeCmdCtrlReprov,
      cmdCtrlReprov: pb.CmdCtrlReprov(),
    ).writeToBuffer(),
  );
}

void ctrlReprovResponse(Uint8List response) {
  final payload = pb.WiFiCtrlPayload.fromBuffer(response);
  _ensureStatus(payload.status, 'Re-provision');
}

Uint8List scanStartRequest(WiFiScanOptions options) {
  return Uint8List.fromList(
    pb.WiFiScanPayload(
      msg: pb.WiFiScanMsgType.TypeCmdScanStart,
      status: pb.Status.Success,
      cmdScanStart: pb.CmdScanStart(
        blocking: options.blocking,
        passive: options.passive,
        groupChannels: options.groupChannels,
        periodMs: options.periodMs,
      ),
    ).writeToBuffer(),
  );
}

void scanStartResponse(Uint8List response) {
  final payload = pb.WiFiScanPayload.fromBuffer(response);
  _ensureStatus(payload.status, 'Start Wi-Fi scan');
}

Uint8List scanStatusRequest() {
  return Uint8List.fromList(
    pb.WiFiScanPayload(
      msg: pb.WiFiScanMsgType.TypeCmdScanStatus,
      status: pb.Status.Success,
      cmdScanStatus: pb.CmdScanStatus(),
    ).writeToBuffer(),
  );
}

int scanStatusResponse(Uint8List response) {
  final payload = pb.WiFiScanPayload.fromBuffer(response);
  _ensureStatus(payload.status, 'Get scan status');
  return payload.hasRespScanStatus() ? payload.respScanStatus.resultCount : 0;
}

Uint8List scanResultRequest({required int startIndex, required int count}) {
  return Uint8List.fromList(
    pb.WiFiScanPayload(
      msg: pb.WiFiScanMsgType.TypeCmdScanResult,
      status: pb.Status.Success,
      cmdScanResult: pb.CmdScanResult(startIndex: startIndex, count: count),
    ).writeToBuffer(),
  );
}

List<WiFiNetwork> scanResultResponse(Uint8List response) {
  final payload = pb.WiFiScanPayload.fromBuffer(response);
  _ensureStatus(payload.status, 'Get scan results');
  return payload.hasRespScanResult()
      ? payload.respScanResult.entries.map(WiFiNetwork.fromProto).toList()
      : const <WiFiNetwork>[];
}

Uint8List configGetStatusRequest() {
  return Uint8List.fromList(
    pb.WiFiConfigPayload(
      msg: pb.WiFiConfigMsgType.TypeCmdGetStatus,
      cmdGetStatus: pb.CmdGetStatus(),
    ).writeToBuffer(),
  );
}

WiFiStatus configGetStatusResponse(Uint8List response) {
  final payload = pb.WiFiConfigPayload.fromBuffer(response);
  if (!payload.hasRespGetStatus()) {
    throw const ProvisionerError('Missing Wi-Fi status response.');
  }
  _ensureStatus(payload.respGetStatus.status, 'Get Wi-Fi status');
  return WiFiStatus.fromProto(payload.respGetStatus);
}

Uint8List configSetConfigRequest(WiFiConfig config) {
  return Uint8List.fromList(
    pb.WiFiConfigPayload(
      msg: pb.WiFiConfigMsgType.TypeCmdSetConfig,
      cmdSetConfig: pb.CmdSetConfig(
        ssid: config.ssidBytes,
        passphrase: config.passphraseBytes,
        bssid: config.bssid,
        channel: config.channel,
      ),
    ).writeToBuffer(),
  );
}

void configSetConfigResponse(Uint8List response) {
  final payload = pb.WiFiConfigPayload.fromBuffer(response);
  if (!payload.hasRespSetConfig()) {
    throw const ProvisionerError('Missing set Wi-Fi config response.');
  }
  _ensureStatus(payload.respSetConfig.status, 'Set Wi-Fi config');
}

Uint8List configApplyConfigRequest() {
  return Uint8List.fromList(
    pb.WiFiConfigPayload(
      msg: pb.WiFiConfigMsgType.TypeCmdApplyConfig,
      cmdApplyConfig: pb.CmdApplyConfig(),
    ).writeToBuffer(),
  );
}

void configApplyConfigResponse(Uint8List response) {
  final payload = pb.WiFiConfigPayload.fromBuffer(response);
  if (!payload.hasRespApplyConfig()) {
    throw const ProvisionerError('Missing apply Wi-Fi config response.');
  }
  _ensureStatus(payload.respApplyConfig.status, 'Apply Wi-Fi config');
}
