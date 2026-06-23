import 'dart:convert';
import 'dart:typed_data';

import 'proto/protos.dart' as pb;

class EspBleDevice {
  const EspBleDevice({required this.id, this.name});

  final String id;
  final String? name;
}

class WiFiScanOptions {
  const WiFiScanOptions({
    this.blocking = true,
    this.passive = false,
    this.groupChannels = 0,
    this.periodMs = 120,
  });

  final bool blocking;
  final bool passive;
  final int groupChannels;
  final int periodMs;
}

class WiFiConfig {
  const WiFiConfig({
    required this.ssid,
    this.passphrase,
    this.bssid,
    this.channel = 0,
  });

  final String ssid;
  final String? passphrase;
  final Uint8List? bssid;
  final int channel;

  Uint8List get ssidBytes => Uint8List.fromList(utf8.encode(ssid));
  Uint8List get passphraseBytes =>
      Uint8List.fromList(utf8.encode(passphrase ?? ''));
}

class WiFiNetwork {
  const WiFiNetwork({
    required this.ssid,
    required this.channel,
    required this.rssi,
    required this.bssid,
    required this.auth,
  });

  final String ssid;
  final int channel;
  final int rssi;
  final Uint8List bssid;
  final pb.WifiAuthMode auth;

  factory WiFiNetwork.fromProto(pb.WiFiScanResult result) {
    return WiFiNetwork(
      ssid: utf8.decode(result.ssid, allowMalformed: true),
      channel: result.channel,
      rssi: result.rssi,
      bssid: Uint8List.fromList(result.bssid),
      auth: result.auth,
    );
  }
}

class WiFiStatus {
  const WiFiStatus({
    required this.state,
    this.failReason,
    this.connected,
    this.attemptsRemaining,
  });

  final pb.WifiStationState state;
  final pb.WifiConnectFailedReason? failReason;
  final WiFiConnectedState? connected;
  final int? attemptsRemaining;

  factory WiFiStatus.fromProto(pb.RespGetStatus status) {
    return WiFiStatus(
      state: status.staState,
      failReason: status.hasFailReason() ? status.failReason : null,
      connected:
          status.hasConnected()
              ? WiFiConnectedState.fromProto(status.connected)
              : null,
      attemptsRemaining:
          status.hasAttemptFailed()
              ? status.attemptFailed.attemptsRemaining
              : null,
    );
  }
}

class WiFiConnectedState {
  const WiFiConnectedState({
    required this.ip4Addr,
    required this.authMode,
    required this.ssid,
    required this.bssid,
    required this.channel,
  });

  final String ip4Addr;
  final pb.WifiAuthMode authMode;
  final String ssid;
  final Uint8List bssid;
  final int channel;

  factory WiFiConnectedState.fromProto(pb.WifiConnectedState state) {
    return WiFiConnectedState(
      ip4Addr: state.ip4Addr,
      authMode: state.authMode,
      ssid: utf8.decode(state.ssid, allowMalformed: true),
      bssid: Uint8List.fromList(state.bssid),
      channel: state.channel,
    );
  }
}
