import 'dart:typed_data';

import 'package:esp_ble_prov_dart/esp_ble_prov_dart.dart';
import 'package:esp_ble_prov_dart/src/proto/protos.dart' as pb;
import 'package:esp_ble_prov_dart/src/prov/proto_commands.dart' as commands;
import 'package:flutter_test/flutter_test.dart';

typedef _Parser = void Function(Uint8List bytes);

void main() {
  group('protobuf response validation', () {
    final cases = <
      ({
        String name,
        _Parser parser,
        Uint8List valid,
        Uint8List wrong,
        Uint8List missing,
        Uint8List failed,
      })
    >[
      (
        name: 'ctrl reset',
        parser: (bytes) => commands.ctrlResetResponse(bytes),
        valid: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReset, reset: true),
        wrong: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReprov, reprov: true),
        missing: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReset),
        failed: _ctrl(
          pb.WiFiCtrlMsgType.TypeRespCtrlReset,
          reset: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'ctrl reprov',
        parser: (bytes) => commands.ctrlReprovResponse(bytes),
        valid: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReprov, reprov: true),
        wrong: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReset, reset: true),
        missing: _ctrl(pb.WiFiCtrlMsgType.TypeRespCtrlReprov),
        failed: _ctrl(
          pb.WiFiCtrlMsgType.TypeRespCtrlReprov,
          reprov: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'scan start',
        parser: (bytes) => commands.scanStartResponse(bytes),
        valid: _scan(pb.WiFiScanMsgType.TypeRespScanStart, start: true),
        wrong: _scan(pb.WiFiScanMsgType.TypeRespScanStatus, scanStatus: true),
        missing: _scan(pb.WiFiScanMsgType.TypeRespScanStart),
        failed: _scan(
          pb.WiFiScanMsgType.TypeRespScanStart,
          start: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'scan status',
        parser: (bytes) => commands.scanStatusResponse(bytes),
        valid: _scan(pb.WiFiScanMsgType.TypeRespScanStatus, scanStatus: true),
        wrong: _scan(pb.WiFiScanMsgType.TypeRespScanStart, start: true),
        missing: _scan(pb.WiFiScanMsgType.TypeRespScanStatus),
        failed: _scan(
          pb.WiFiScanMsgType.TypeRespScanStatus,
          scanStatus: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'scan result',
        parser: (bytes) => commands.scanResultResponse(bytes),
        valid: _scan(pb.WiFiScanMsgType.TypeRespScanResult, result: true),
        wrong: _scan(pb.WiFiScanMsgType.TypeRespScanStart, start: true),
        missing: _scan(pb.WiFiScanMsgType.TypeRespScanResult),
        failed: _scan(
          pb.WiFiScanMsgType.TypeRespScanResult,
          result: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'config status',
        parser: (bytes) => commands.configGetStatusResponse(bytes),
        valid: _config(pb.WiFiConfigMsgType.TypeRespGetStatus, getStatus: true),
        wrong: _config(pb.WiFiConfigMsgType.TypeRespSetConfig, setConfig: true),
        missing: _config(pb.WiFiConfigMsgType.TypeRespGetStatus),
        failed: _config(
          pb.WiFiConfigMsgType.TypeRespGetStatus,
          getStatus: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'set config',
        parser: (bytes) => commands.configSetConfigResponse(bytes),
        valid: _config(pb.WiFiConfigMsgType.TypeRespSetConfig, setConfig: true),
        wrong: _config(pb.WiFiConfigMsgType.TypeRespApplyConfig, apply: true),
        missing: _config(pb.WiFiConfigMsgType.TypeRespSetConfig),
        failed: _config(
          pb.WiFiConfigMsgType.TypeRespSetConfig,
          setConfig: true,
          status: pb.Status.InternalError,
        ),
      ),
      (
        name: 'apply config',
        parser: (bytes) => commands.configApplyConfigResponse(bytes),
        valid: _config(pb.WiFiConfigMsgType.TypeRespApplyConfig, apply: true),
        wrong: _config(pb.WiFiConfigMsgType.TypeRespSetConfig, setConfig: true),
        missing: _config(pb.WiFiConfigMsgType.TypeRespApplyConfig),
        failed: _config(
          pb.WiFiConfigMsgType.TypeRespApplyConfig,
          apply: true,
          status: pb.Status.InternalError,
        ),
      ),
    ];

    for (final testCase in cases) {
      test('${testCase.name}: accepts valid response', () {
        expect(() => testCase.parser(testCase.valid), returnsNormally);
      });
      test('${testCase.name}: rejects wrong message type', () {
        expect(
          () => testCase.parser(testCase.wrong),
          throwsA(isA<ProvisionerError>()),
        );
      });
      test('${testCase.name}: rejects missing payload', () {
        expect(
          () => testCase.parser(testCase.missing),
          throwsA(isA<ProvisionerError>()),
        );
      });
      test('${testCase.name}: rejects non-success status', () {
        expect(
          () => testCase.parser(testCase.failed),
          throwsA(isA<ProvisionerError>()),
        );
      });
      test('${testCase.name}: rejects malformed protobuf', () {
        expect(
          () => testCase.parser(Uint8List.fromList([0xff, 0xff])),
          throwsA(anything),
        );
      });
    }
  });

  group('request boundary validation', () {
    test('accepts 32-byte multi-byte SSID and 64-byte passphrase', () {
      final request = commands.configSetConfigRequest(
        WiFiConfig(
          ssid: List.filled(16, 'é').join(),
          passphrase: List.filled(64, 'p').join(),
          bssid: [1, 2, 3, 4, 5, 6],
          channel: 14,
        ),
      );
      final payload = pb.WiFiConfigPayload.fromBuffer(request);
      expect(payload.cmdSetConfig.ssid, hasLength(32));
      expect(payload.cmdSetConfig.passphrase, hasLength(64));
    });

    test('rejects SSID over 32 UTF-8 bytes', () {
      expect(
        () => commands.configSetConfigRequest(
          WiFiConfig(ssid: List.filled(17, 'é').join()),
        ),
        throwsA(isA<ProvisionerError>()),
      );
    });

    test('rejects passphrase over 64 bytes', () {
      expect(
        () => commands.configSetConfigRequest(
          WiFiConfig(ssid: 'ok', passphrase: List.filled(65, 'p').join()),
        ),
        throwsA(isA<ProvisionerError>()),
      );
    });

    for (final bssid in <List<int>>[
      [1, 2, 3, 4, 5],
      [1, 2, 3, 4, 5, 6, 7],
    ]) {
      test('rejects ${bssid.length}-byte BSSID', () {
        expect(
          () => commands.configSetConfigRequest(
            WiFiConfig(ssid: 'ok', bssid: bssid),
          ),
          throwsA(isA<ProvisionerError>()),
        );
      });
    }

    for (final channel in [-1, 15]) {
      test('rejects channel $channel', () {
        expect(
          () => commands.configSetConfigRequest(
            WiFiConfig(ssid: 'ok', channel: channel),
          ),
          throwsA(isA<ProvisionerError>()),
        );
      });
    }

    test('validates scan options and result ranges', () {
      expect(
        () =>
            commands.scanStartRequest(const WiFiScanOptions(groupChannels: -1)),
        throwsA(isA<ProvisionerError>()),
      );
      expect(
        () => commands.scanStartRequest(const WiFiScanOptions(periodMs: -1)),
        throwsA(isA<ProvisionerError>()),
      );
      expect(
        () => commands.scanResultRequest(startIndex: -1, count: 1),
        throwsA(isA<ProvisionerError>()),
      );
      expect(
        () => commands.scanResultRequest(startIndex: 0, count: 0),
        throwsA(isA<ProvisionerError>()),
      );
    });
  });
}

Uint8List _ctrl(
  pb.WiFiCtrlMsgType type, {
  bool reset = false,
  bool reprov = false,
  pb.Status status = pb.Status.Success,
}) => Uint8List.fromList(
  pb.WiFiCtrlPayload(
    msg: type,
    status: status,
    cmdCtrlReset: null,
    respCtrlReset: reset ? pb.RespCtrlReset() : null,
    respCtrlReprov: reprov ? pb.RespCtrlReprov() : null,
  ).writeToBuffer(),
);

Uint8List _scan(
  pb.WiFiScanMsgType type, {
  bool start = false,
  bool scanStatus = false,
  bool result = false,
  pb.Status status = pb.Status.Success,
}) => Uint8List.fromList(
  pb.WiFiScanPayload(
    msg: type,
    status: status,
    respScanStart: start ? pb.RespScanStart() : null,
    respScanStatus: scanStatus ? pb.RespScanStatus(scanFinished: true) : null,
    respScanResult: result ? pb.RespScanResult() : null,
  ).writeToBuffer(),
);

Uint8List _config(
  pb.WiFiConfigMsgType type, {
  bool getStatus = false,
  bool setConfig = false,
  bool apply = false,
  pb.Status status = pb.Status.Success,
}) => Uint8List.fromList(
  pb.WiFiConfigPayload(
    msg: type,
    respGetStatus:
        getStatus
            ? pb.RespGetStatus(
              status: status,
              staState: pb.WifiStationState.Disconnected,
            )
            : null,
    respSetConfig: setConfig ? pb.RespSetConfig(status: status) : null,
    respApplyConfig: apply ? pb.RespApplyConfig(status: status) : null,
  ).writeToBuffer(),
);
