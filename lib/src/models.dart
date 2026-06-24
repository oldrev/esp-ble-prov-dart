import 'dart:convert';
import 'dart:typed_data';

import 'proto/protos.dart' as pb;

/// BLE device discovered during ESP provisioning scans.
class EspBleDevice {
  /// Creates a discovered ESP provisioning device.
  const EspBleDevice({required this.id, this.name});

  /// Platform-specific BLE device identifier used for connecting.
  final String id;

  /// Advertised device name, when available.
  final String? name;
}

/// Options sent to the ESP device before requesting Wi-Fi scan results.
class WiFiScanOptions {
  /// Creates Wi-Fi scan options.
  const WiFiScanOptions({
    this.blocking = true,
    this.passive = false,
    this.groupChannels = 0,
    this.periodMs = 120,
  });

  /// Whether the device should block until the scan completes.
  final bool blocking;

  /// Whether the scan should use passive channel listening.
  final bool passive;

  /// Number of channels scanned in each group.
  ///
  /// `0` keeps the ESP-IDF firmware default.
  final int groupChannels;

  /// Delay between grouped channel scans in milliseconds.
  final int periodMs;
}

/// Wi-Fi credentials and optional access point hints sent to the ESP device.
class WiFiConfig {
  /// Creates a Wi-Fi configuration for [ssid].
  const WiFiConfig({
    required this.ssid,
    this.passphrase,
    this.bssid,
    this.channel = 0,
  });

  /// Wi-Fi SSID encoded as UTF-8 for the provisioning protocol.
  final String ssid;

  /// Wi-Fi password. Leave `null` for open networks.
  final String? passphrase;

  /// Optional BSSID to target a specific access point.
  final Uint8List? bssid;

  /// Optional Wi-Fi channel hint. `0` lets the device choose automatically.
  final int channel;

  /// UTF-8 encoded [ssid].
  Uint8List get ssidBytes => Uint8List.fromList(utf8.encode(ssid));

  /// UTF-8 encoded [passphrase], or an empty byte list when no passphrase is
  /// set.
  Uint8List get passphraseBytes =>
      Uint8List.fromList(utf8.encode(passphrase ?? ''));
}

/// Wi-Fi access point returned by the provisioning scan endpoint.
class WiFiNetwork {
  /// Creates a scanned Wi-Fi network record.
  const WiFiNetwork({
    required this.ssid,
    required this.channel,
    required this.rssi,
    required this.bssid,
    required this.auth,
  });

  /// Access point SSID decoded as UTF-8.
  final String ssid;

  /// Wi-Fi channel used by the access point.
  final int channel;

  /// Received signal strength indicator in dBm.
  final int rssi;

  /// Access point BSSID.
  final Uint8List bssid;

  /// Authentication mode reported by the ESP device.
  final pb.WifiAuthMode auth;

  /// Converts a protobuf scan result into a public model.
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

/// Current Wi-Fi station status reported by the ESP device.
class WiFiStatus {
  /// Creates a Wi-Fi status snapshot.
  const WiFiStatus({
    required this.state,
    this.failReason,
    this.connected,
    this.attemptsRemaining,
  });

  /// ESP station state.
  final pb.WifiStationState state;

  /// Failure reason when [state] indicates a connection failure.
  final pb.WifiConnectFailedReason? failReason;

  /// Connected network details when [state] is connected.
  final WiFiConnectedState? connected;

  /// Remaining connection attempts after a failed attempt, when reported.
  final int? attemptsRemaining;

  /// Converts a protobuf status response into a public model.
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

/// Details reported when the ESP station is connected to Wi-Fi.
class WiFiConnectedState {
  /// Creates a connected Wi-Fi state snapshot.
  const WiFiConnectedState({
    required this.ip4Addr,
    required this.authMode,
    required this.ssid,
    required this.bssid,
    required this.channel,
  });

  /// IPv4 address assigned to the ESP device.
  final String ip4Addr;

  /// Authentication mode of the connected access point.
  final pb.WifiAuthMode authMode;

  /// Connected SSID decoded as UTF-8.
  final String ssid;

  /// Connected access point BSSID.
  final Uint8List bssid;

  /// Connected Wi-Fi channel.
  final int channel;

  /// Converts a protobuf connected-state message into a public model.
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
