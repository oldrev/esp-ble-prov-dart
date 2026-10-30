import 'dart:convert';
import 'dart:typed_data';

/// Authentication mode reported by an ESP Wi-Fi station or scan result.
enum WiFiAuthMode {
  open(0),
  wep(1),
  wpaPsk(2),
  wpa2Psk(3),
  wpaWpa2Psk(4),
  wpa2Enterprise(5),
  wpa3Psk(6),
  wpa2Wpa3Psk(7),
  unknown(-1);

  const WiFiAuthMode(this.protocolValue);
  final int protocolValue;

  static WiFiAuthMode fromProtocolValue(int value) => values.firstWhere(
    (mode) => mode.protocolValue == value,
    orElse: () => unknown,
  );
}

/// Current ESP Wi-Fi station state.
enum WiFiStationState {
  connected(0),
  connecting(1),
  disconnected(2),
  connectionFailed(3),
  unknown(-1);

  const WiFiStationState(this.protocolValue);
  final int protocolValue;

  static WiFiStationState fromProtocolValue(int value) => values.firstWhere(
    (state) => state.protocolValue == value,
    orElse: () => unknown,
  );
}

/// Reason reported when an ESP cannot join the requested network.
enum WiFiConnectFailureReason {
  authenticationError(0),
  networkNotFound(1),
  unknown(-1);

  const WiFiConnectFailureReason(this.protocolValue);
  final int protocolValue;

  static WiFiConnectFailureReason fromProtocolValue(int value) =>
      values.firstWhere(
        (reason) => reason.protocolValue == value,
        orElse: () => unknown,
      );
}

/// BLE device discovered or authorized for ESP provisioning.
class EspBleDevice {
  const EspBleDevice({required this.id, this.name});

  final String id;
  final String? name;

  @override
  bool operator ==(Object other) =>
      other is EspBleDevice && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'EspBleDevice(id: $id, name: $name)';
}

/// Options sent to the ESP device before requesting Wi-Fi scan results.
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

  @override
  bool operator ==(Object other) =>
      other is WiFiScanOptions &&
      other.blocking == blocking &&
      other.passive == passive &&
      other.groupChannels == groupChannels &&
      other.periodMs == periodMs;

  @override
  int get hashCode => Object.hash(blocking, passive, groupChannels, periodMs);
}

/// Wi-Fi scan progress reported by the ESP device.
class WiFiScanStatus {
  const WiFiScanStatus({required this.scanFinished, required this.resultCount});

  final bool scanFinished;
  final int resultCount;

  @override
  bool operator ==(Object other) =>
      other is WiFiScanStatus &&
      other.scanFinished == scanFinished &&
      other.resultCount == resultCount;

  @override
  int get hashCode => Object.hash(scanFinished, resultCount);
}

/// Wi-Fi credentials and optional access point hints sent to the ESP device.
class WiFiConfig {
  WiFiConfig({
    required this.ssid,
    this.passphrase,
    List<int>? bssid,
    this.channel = 0,
  }) : _bssid = bssid == null ? null : Uint8List.fromList(bssid);

  final String ssid;
  final String? passphrase;
  final Uint8List? _bssid;
  final int channel;

  Uint8List? get bssid => _bssid?.asUnmodifiableView();
  Uint8List get ssidBytes => Uint8List.fromList(utf8.encode(ssid));
  Uint8List get passphraseBytes =>
      Uint8List.fromList(utf8.encode(passphrase ?? ''));

  @override
  bool operator ==(Object other) =>
      other is WiFiConfig &&
      other.ssid == ssid &&
      other.passphrase == passphrase &&
      _bytesEqual(other._bssid, _bssid) &&
      other.channel == channel;

  @override
  int get hashCode => Object.hash(
    ssid,
    passphrase,
    Object.hashAll(_bssid ?? const <int>[]),
    channel,
  );

  @override
  String toString() =>
      'WiFiConfig(ssid: $ssid, passphrase: <redacted>, channel: $channel)';
}

/// Wi-Fi access point returned by the provisioning scan endpoint.
class WiFiNetwork {
  WiFiNetwork({
    required this.ssid,
    required this.channel,
    required this.rssi,
    required List<int> bssid,
    required this.auth,
  }) : _bssid = Uint8List.fromList(bssid);

  final String ssid;
  final int channel;
  final int rssi;
  final Uint8List _bssid;
  final WiFiAuthMode auth;

  Uint8List get bssid => _bssid.asUnmodifiableView();

  @override
  bool operator ==(Object other) =>
      other is WiFiNetwork &&
      other.ssid == ssid &&
      other.channel == channel &&
      other.rssi == rssi &&
      _bytesEqual(other._bssid, _bssid) &&
      other.auth == auth;

  @override
  int get hashCode =>
      Object.hash(ssid, channel, rssi, Object.hashAll(_bssid), auth);

  @override
  String toString() =>
      'WiFiNetwork(ssid: $ssid, channel: $channel, rssi: $rssi, auth: $auth)';
}

/// Current Wi-Fi station status reported by the ESP device.
class WiFiStatus {
  const WiFiStatus({
    required this.state,
    this.failReason,
    this.connected,
    this.attemptsRemaining,
  });

  final WiFiStationState state;
  final WiFiConnectFailureReason? failReason;
  final WiFiConnectedState? connected;
  final int? attemptsRemaining;

  @override
  bool operator ==(Object other) =>
      other is WiFiStatus &&
      other.state == state &&
      other.failReason == failReason &&
      other.connected == connected &&
      other.attemptsRemaining == attemptsRemaining;

  @override
  int get hashCode =>
      Object.hash(state, failReason, connected, attemptsRemaining);
}

/// Details reported when the ESP station is connected to Wi-Fi.
class WiFiConnectedState {
  WiFiConnectedState({
    required this.ip4Addr,
    required this.authMode,
    required this.ssid,
    required List<int> bssid,
    required this.channel,
  }) : _bssid = Uint8List.fromList(bssid);

  final String ip4Addr;
  final WiFiAuthMode authMode;
  final String ssid;
  final Uint8List _bssid;
  final int channel;

  Uint8List get bssid => _bssid.asUnmodifiableView();

  @override
  bool operator ==(Object other) =>
      other is WiFiConnectedState &&
      other.ip4Addr == ip4Addr &&
      other.authMode == authMode &&
      other.ssid == ssid &&
      _bytesEqual(other._bssid, _bssid) &&
      other.channel == channel;

  @override
  int get hashCode =>
      Object.hash(ip4Addr, authMode, ssid, Object.hashAll(_bssid), channel);
}

bool _bytesEqual(List<int>? a, List<int>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
