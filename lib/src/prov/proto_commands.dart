import 'dart:convert';
import 'dart:typed_data';

import '../models.dart';
import '../proto/protos.dart' as pb;
import '../provisioner_error.dart';

void _ensureStatus(pb.Status status, String operation) {
  if (status != pb.Status.Success) {
    throw ProvisionerError('$operation failed: ${status.name}');
  }
}

void _ensureMessage<T>(T actual, T expected, String operation) {
  if (actual != expected) {
    throw ProvisionerError(
      '$operation returned unexpected message type: $actual.',
    );
  }
}

void _validateScanOptions(WiFiScanOptions options) {
  if (options.groupChannels < 0) {
    throw const ProvisionerError('Wi-Fi scan groupChannels must be >= 0.');
  }
  if (options.periodMs < 0) {
    throw const ProvisionerError('Wi-Fi scan periodMs must be >= 0.');
  }
}

void _validateScanResultRange({required int startIndex, required int count}) {
  if (startIndex < 0) {
    throw const ProvisionerError('Wi-Fi scan startIndex must be >= 0.');
  }
  if (count <= 0) {
    throw const ProvisionerError('Wi-Fi scan result count must be > 0.');
  }
}

void _validateWiFiConfig(WiFiConfig config) {
  final ssidBytes = config.ssidBytes;
  if (ssidBytes.isEmpty || ssidBytes.length > 32) {
    throw ProvisionerError(
      'Wi-Fi SSID must be 1..32 UTF-8 bytes, got ${ssidBytes.length}.',
    );
  }

  final passphraseBytes = config.passphraseBytes;
  if (passphraseBytes.length > 64) {
    throw ProvisionerError(
      'Wi-Fi passphrase must be <= 64 UTF-8 bytes, got '
      '${passphraseBytes.length}.',
    );
  }

  final bssid = config.bssid;
  if (bssid != null && bssid.length != 6) {
    throw ProvisionerError('Wi-Fi BSSID must be 6 bytes, got ${bssid.length}.');
  }

  if (config.channel < 0 || config.channel > 14) {
    throw ProvisionerError(
      'Wi-Fi channel must be in range 0..14, got ${config.channel}.',
    );
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
  _ensureMessage(
    payload.msg,
    pb.WiFiCtrlMsgType.TypeRespCtrlReset,
    'Reset provisioning state',
  );
  if (!payload.hasRespCtrlReset()) {
    throw const ProvisionerError('Missing reset provisioning response.');
  }
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
  _ensureMessage(
    payload.msg,
    pb.WiFiCtrlMsgType.TypeRespCtrlReprov,
    'Re-provision',
  );
  if (!payload.hasRespCtrlReprov()) {
    throw const ProvisionerError('Missing re-provision response.');
  }
  _ensureStatus(payload.status, 'Re-provision');
}

Uint8List scanStartRequest(WiFiScanOptions options) {
  _validateScanOptions(options);
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
  _ensureMessage(
    payload.msg,
    pb.WiFiScanMsgType.TypeRespScanStart,
    'Start Wi-Fi scan',
  );
  if (!payload.hasRespScanStart()) {
    throw const ProvisionerError('Missing start Wi-Fi scan response.');
  }
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

WiFiScanStatus scanStatusResponse(Uint8List response) {
  final payload = pb.WiFiScanPayload.fromBuffer(response);
  _ensureMessage(
    payload.msg,
    pb.WiFiScanMsgType.TypeRespScanStatus,
    'Get scan status',
  );
  if (!payload.hasRespScanStatus()) {
    throw const ProvisionerError('Missing Wi-Fi scan status response.');
  }
  _ensureStatus(payload.status, 'Get scan status');
  final status = payload.respScanStatus;
  return WiFiScanStatus(
    scanFinished: status.scanFinished,
    resultCount: status.resultCount,
  );
}

Uint8List scanResultRequest({required int startIndex, required int count}) {
  _validateScanResultRange(startIndex: startIndex, count: count);
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
  _ensureMessage(
    payload.msg,
    pb.WiFiScanMsgType.TypeRespScanResult,
    'Get scan results',
  );
  if (!payload.hasRespScanResult()) {
    throw const ProvisionerError('Missing Wi-Fi scan result response.');
  }
  _ensureStatus(payload.status, 'Get scan results');
  return payload.respScanResult.entries
      .map(
        (entry) => WiFiNetwork(
          ssid: utf8.decode(entry.ssid, allowMalformed: true),
          channel: entry.channel,
          rssi: entry.rssi,
          bssid: entry.bssid,
          auth: WiFiAuthMode.fromProtocolValue(entry.auth.value),
        ),
      )
      .toList();
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
  _ensureMessage(
    payload.msg,
    pb.WiFiConfigMsgType.TypeRespGetStatus,
    'Get Wi-Fi status',
  );
  if (!payload.hasRespGetStatus()) {
    throw const ProvisionerError('Missing Wi-Fi status response.');
  }
  _ensureStatus(payload.respGetStatus.status, 'Get Wi-Fi status');
  final status = payload.respGetStatus;
  final connected = status.hasConnected() ? status.connected : null;
  return WiFiStatus(
    state: WiFiStationState.fromProtocolValue(status.staState.value),
    failReason:
        status.hasFailReason()
            ? WiFiConnectFailureReason.fromProtocolValue(
              status.failReason.value,
            )
            : null,
    connected:
        connected == null
            ? null
            : WiFiConnectedState(
              ip4Addr: connected.ip4Addr,
              authMode: WiFiAuthMode.fromProtocolValue(
                connected.authMode.value,
              ),
              ssid: utf8.decode(connected.ssid, allowMalformed: true),
              bssid: connected.bssid,
              channel: connected.channel,
            ),
    attemptsRemaining:
        status.hasAttemptFailed()
            ? status.attemptFailed.attemptsRemaining
            : null,
  );
}

Uint8List configSetConfigRequest(WiFiConfig config) {
  _validateWiFiConfig(config);
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
  _ensureMessage(
    payload.msg,
    pb.WiFiConfigMsgType.TypeRespSetConfig,
    'Set Wi-Fi config',
  );
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
  _ensureMessage(
    payload.msg,
    pb.WiFiConfigMsgType.TypeRespApplyConfig,
    'Apply Wi-Fi config',
  );
  if (!payload.hasRespApplyConfig()) {
    throw const ProvisionerError('Missing apply Wi-Fi config response.');
  }
  _ensureStatus(payload.respApplyConfig.status, 'Apply Wi-Fi config');
}
