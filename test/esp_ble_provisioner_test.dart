import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:cryptography/cryptography.dart';
import 'package:esp_ble_prov_dart/esp_ble_prov_dart.dart';
import 'package:esp_ble_prov_dart/src/ble/esp_ble_transport.dart';
import 'package:esp_ble_prov_dart/src/proto/protos.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  const serviceUuid = '0000ffff-0000-1000-8000-00805f9b34fb';
  const endpoints = {
    provCtrlEndpoint: '0000ff4f-0000-1000-8000-00805f9b34fb',
    provScanEndpoint: '0000ff50-0000-1000-8000-00805f9b34fb',
    provSessionEndpoint: '0000ff51-0000-1000-8000-00805f9b34fb',
    provConfigEndpoint: '0000ff52-0000-1000-8000-00805f9b34fb',
    protoVerEndpoint: '0000ff53-0000-1000-8000-00805f9b34fb',
  };

  test('establishes a Security0 session', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    await provisioner.establishSession();

    expect(transport.requestedMtu, 517);
    expect(transport.writes, hasLength(1));
    final session = pb.SessionData.fromBuffer(transport.writes.single.value);
    expect(session.secVer, pb.SecSchemeVersion.SecScheme0);
    expect(session.sec0.msg, pb.Sec0MsgType.S0_Session_Command);
  });

  test('scans Wi-Fi networks through provisioning endpoints', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    final networks = await provisioner.scan();

    expect(networks, hasLength(1));
    expect(networks.single.ssid, 'Lab WiFi');
    expect(networks.single.channel, 6);
    expect(networks.single.auth, pb.WifiAuthMode.WPA2_PSK);
  });

  test('sends credentials and returns connected status', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    final status = await provisioner.sendCredentials(
      const WiFiConfig(ssid: 'Lab WiFi', passphrase: 'secret'),
    );

    expect(status.state, pb.WifiStationState.Connected);
    expect(status.connected?.ssid, 'Lab WiFi');

    final setConfigWrite = transport.decodedConfigWrites.singleWhere(
      (payload) => payload.msg == pb.WiFiConfigMsgType.TypeCmdSetConfig,
    );
    expect(String.fromCharCodes(setConfigWrite.cmdSetConfig.ssid), 'Lab WiFi');
    expect(
      String.fromCharCodes(setConfigWrite.cmdSetConfig.passphrase),
      'secret',
    );
  });

  test('derives default endpoint UUIDs from service UUID', () {
    expect(deriveEspProvisioningEndpointUuids(serviceUuid), endpoints);
  });

  test('derives custom endpoint UUIDs from ESP-IDF custom endpoint index', () {
    expect(espProvisioningCustomEndpointShortUuid(0), 0xff54);
    expect(espProvisioningCustomEndpointShortUuid(1), 0xff55);
    expect(
      deriveEspProvisioningCustomEndpointUuid(serviceUuid, 0),
      '0000ff54-0000-1000-8000-00805f9b34fb',
    );
  });

  test('Security1 completes proof exchange with a simulated device', () async {
    final host = Security1(pop: 'abcd1234');
    final command0 = pb.SessionData.fromBuffer(await host.setup0Request());
    final clientPublicKey = Uint8List.fromList(command0.sec1.sc0.clientPubkey);

    final device = await _Security1Device.create(
      clientPublicKey: clientPublicKey,
      pop: 'abcd1234',
    );

    await host.setup0Response(device.command0Response());
    final command1 = pb.SessionData.fromBuffer((await host.setup1Request())!);
    final command1Response = await device.command1Response(
      Uint8List.fromList(command1.sec1.sc1.clientVerifyData),
    );

    await host.setup1Response(command1Response);
    final cipherText = await host.encrypt(Uint8List.fromList([1, 2, 3, 4]));
    expect(cipherText, isNot(equals([1, 2, 3, 4])));
    expect(await device.decrypt(cipherText), [1, 2, 3, 4]);
  });

  test('Security1 keeps CTR state aligned after short messages', () async {
    final host = Security1();
    final command0 = pb.SessionData.fromBuffer(await host.setup0Request());
    final clientPublicKey = Uint8List.fromList(command0.sec1.sc0.clientPubkey);

    final device = await _Security1Device.create(
      clientPublicKey: clientPublicKey,
      pop: '',
    );

    await host.setup0Response(device.command0Response());
    final command1 = pb.SessionData.fromBuffer((await host.setup1Request())!);
    final command1Response = await device.command1Response(
      Uint8List.fromList(command1.sec1.sc1.clientVerifyData),
    );
    await host.setup1Response(command1Response);

    final encryptedRequest = await host.encrypt(
      Uint8List.fromList(List<int>.generate(14, (index) => index)),
    );
    expect(await device.decrypt(encryptedRequest), hasLength(14));

    final encryptedResponse = await device.encrypt(Uint8List.fromList([9, 8]));
    expect(await host.decrypt(encryptedResponse), [9, 8]);
  });

  test('Dart AES-CTR matches the JavaScript aes-js reference stream', () async {
    const aes = DartAesCtr.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      counterBits: 128,
    );
    final key = SecretKey(List<int>.generate(32, (index) => index));
    final nonce = List<int>.generate(16, (index) => 0xa0 + index);

    final first = await aes.encrypt(
      Uint8List.fromList(List<int>.generate(14, (index) => index)),
      secretKey: key,
      nonce: nonce,
    );
    final second = await aes.encrypt(
      Uint8List.fromList([1, 2, 3, 4, 5]),
      secretKey: key,
      nonce: nonce,
      keyStreamIndex: 14,
    );

    expect(first.cipherText, [
      0xdc,
      0x9e,
      0x03,
      0xfe,
      0x72,
      0xbd,
      0x7a,
      0x0a,
      0x07,
      0x42,
      0xe2,
      0x8e,
      0x07,
      0x06,
    ]);
    expect(second.cipherText, [0xed, 0xe2, 0xe2, 0xd5, 0xee]);
  });

  test('throws when an overridden endpoint UUID is not found', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      endpointUuids: {provScanEndpoint: '0000aaaa-0000-1000-8000-00805f9b34fb'},
      transport: transport,
    );

    expect(
      () => provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      ),
      throwsA(isA<ProvisionerError>()),
    );
  });

  test('detects proto-ver JSON on encrypted endpoint reads', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      protoVersionResponseOnScan: true,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    await expectLater(
      provisioner.startScan(),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.message,
          'message',
          contains('read proto-ver JSON'),
        ),
      ),
    );
  });

  test('disconnects when connect fails during service discovery', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        provSessionEndpoint: '0000aa51-0000-1000-8000-00805f9b34fb',
        provConfigEndpoint: '0000aa52-0000-1000-8000-00805f9b34fb',
        provScanEndpoint: '0000aa53-0000-1000-8000-00805f9b34fb',
        provCtrlEndpoint: '0000aa54-0000-1000-8000-00805f9b34fb',
      },
      discoveredServiceUuid: '00001234-0000-1000-8000-00805f9b34fb',
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await expectLater(
      provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      ),
      throwsA(isA<ProvisionerError>()),
    );

    expect(provisioner.isConnected, isFalse);
    expect(transport.disconnects, 1);
  });

  test('supports custom endpoint registration after connect', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        ...endpoints,
        'device-id': '0000aaaa-0000-1000-8000-00805f9b34fb',
      },
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    provisioner.registerEndpoint(
      'device-id',
      '0000aaaa-0000-1000-8000-00805f9b34fb',
    );

    await provisioner.writeValueToEndpoint(
      'device-id',
      Uint8List.fromList([10, 20, 30]),
    );

    expect(
      transport.writes.last.characteristic,
      '0000aaaa-0000-1000-8000-00805f9b34fb',
    );
  });

  test('supports custom endpoint registration by ESP-IDF index', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        ...endpoints,
        'device-id': '0000ff54-0000-1000-8000-00805f9b34fb',
      },
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    provisioner.registerCustomEndpoint('device-id');

    await provisioner.writeValueToEndpoint(
      'device-id',
      Uint8List.fromList([10, 20, 30]),
    );

    expect(
      transport.writes.last.characteristic,
      '0000ff54-0000-1000-8000-00805f9b34fb',
    );
  });
}

EspBleProvisioner _provisioner(
  _FakeTransport transport,
  String serviceUuid,
  Map<String, String> endpoints,
) {
  return EspBleProvisioner(
    serviceUuid: serviceUuid,
    transport: transport,
    security: const Security0(),
  );
}

class _WriteRecord {
  const _WriteRecord({required this.characteristic, required this.value});

  final String characteristic;
  final Uint8List value;
}

class _FakeTransport implements EspBleTransport {
  _FakeTransport({
    required this.serviceUuid,
    required this.endpoints,
    String? discoveredServiceUuid,
    this.protoVersionResponseOnScan = false,
  }) : discoveredServiceUuid = discoveredServiceUuid ?? serviceUuid;

  final String serviceUuid;
  final String discoveredServiceUuid;
  final Map<String, String> endpoints;
  final bool protoVersionResponseOnScan;
  final _scanController = StreamController<BleDevice>.broadcast();
  final List<_WriteRecord> writes = [];
  final List<pb.WiFiConfigPayload> decodedConfigWrites = [];
  int disconnects = 0;
  int? requestedMtu;

  Uint8List _nextRead = Uint8List(0);
  bool _connected = false;

  @override
  Stream<BleDevice> get scanStream => _scanController.stream;

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    _scanController.add(BleDevice(deviceId: 'device-1', name: 'BOPROV_TEST'));
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    _connected = true;
  }

  @override
  Future<void> disconnect(String deviceId, {Duration? timeout}) async {
    disconnects++;
    _connected = false;
  }

  @override
  Future<int> requestMtu(
    String deviceId,
    int expectedMtu, {
    Duration? timeout,
  }) async {
    requestedMtu = expectedMtu;
    return expectedMtu;
  }

  @override
  Future<List<BleService>> discoverServices(
    String deviceId, {
    bool withDescriptors = false,
  }) async {
    if (!_connected) throw StateError('not connected');
    return [
      BleService(
        discoveredServiceUuid,
        endpoints.values
            .map(
              (uuid) => BleCharacteristic(uuid, [
                CharacteristicProperty.read,
                CharacteristicProperty.write,
              ], []),
            )
            .toList(),
      ),
    ];
  }

  @override
  Future<Uint8List> read(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    Duration? timeout,
  }) async {
    return _nextRead;
  }

  @override
  Future<void> write(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List value, {
    bool withoutResponse = false,
    Duration? timeout,
  }) async {
    writes.add(_WriteRecord(characteristic: characteristicUuid, value: value));

    if (_same(characteristicUuid, endpoints[provSessionEndpoint]!)) {
      _nextRead = Uint8List.fromList(
        pb.SessionData(
          secVer: pb.SecSchemeVersion.SecScheme0,
          sec0: pb.Sec0Payload(
            msg: pb.Sec0MsgType.S0_Session_Response,
            sr: pb.S0SessionResp(status: pb.Status.Success),
          ),
        ).writeToBuffer(),
      );
      return;
    }

    if (_same(characteristicUuid, endpoints[provScanEndpoint]!)) {
      if (protoVersionResponseOnScan) {
        _nextRead = Uint8List.fromList(
          '{"prov":{"ver":"netprov-v1.1"}}'.codeUnits,
        );
        return;
      }

      final request = pb.WiFiScanPayload.fromBuffer(value);
      switch (request.msg) {
        case pb.WiFiScanMsgType.TypeCmdScanStart:
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanStart,
              status: pb.Status.Success,
              respScanStart: pb.RespScanStart(),
            ).writeToBuffer(),
          );
        case pb.WiFiScanMsgType.TypeCmdScanStatus:
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanStatus,
              status: pb.Status.Success,
              respScanStatus: pb.RespScanStatus(
                scanFinished: true,
                resultCount: 1,
              ),
            ).writeToBuffer(),
          );
        case pb.WiFiScanMsgType.TypeCmdScanResult:
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanResult,
              status: pb.Status.Success,
              respScanResult: pb.RespScanResult(
                entries: [
                  pb.WiFiScanResult(
                    ssid: 'Lab WiFi'.codeUnits,
                    channel: 6,
                    rssi: -42,
                    bssid: [1, 2, 3, 4, 5, 6],
                    auth: pb.WifiAuthMode.WPA2_PSK,
                  ),
                ],
              ),
            ).writeToBuffer(),
          );
        default:
          throw StateError('unexpected scan request: ${request.msg}');
      }
      return;
    }

    if (_same(characteristicUuid, endpoints[provConfigEndpoint]!)) {
      final request = pb.WiFiConfigPayload.fromBuffer(value);
      decodedConfigWrites.add(request);
      switch (request.msg) {
        case pb.WiFiConfigMsgType.TypeCmdSetConfig:
          _nextRead = Uint8List.fromList(
            pb.WiFiConfigPayload(
              msg: pb.WiFiConfigMsgType.TypeRespSetConfig,
              respSetConfig: pb.RespSetConfig(status: pb.Status.Success),
            ).writeToBuffer(),
          );
        case pb.WiFiConfigMsgType.TypeCmdApplyConfig:
          _nextRead = Uint8List.fromList(
            pb.WiFiConfigPayload(
              msg: pb.WiFiConfigMsgType.TypeRespApplyConfig,
              respApplyConfig: pb.RespApplyConfig(status: pb.Status.Success),
            ).writeToBuffer(),
          );
        case pb.WiFiConfigMsgType.TypeCmdGetStatus:
          _nextRead = Uint8List.fromList(
            pb.WiFiConfigPayload(
              msg: pb.WiFiConfigMsgType.TypeRespGetStatus,
              respGetStatus: pb.RespGetStatus(
                status: pb.Status.Success,
                staState: pb.WifiStationState.Connected,
                connected: pb.WifiConnectedState(
                  ip4Addr: '192.168.4.2',
                  authMode: pb.WifiAuthMode.WPA2_PSK,
                  ssid: 'Lab WiFi'.codeUnits,
                  bssid: [1, 2, 3, 4, 5, 6],
                  channel: 6,
                ),
              ),
            ).writeToBuffer(),
          );
        default:
          throw StateError('unexpected config request: ${request.msg}');
      }
    }
  }

  bool _same(String a, String b) =>
      BleUuidParser.string(a) == BleUuidParser.string(b);
}

class _Security1Device {
  _Security1Device._({
    required this.clientPublicKey,
    required this.publicKey,
    required this.deviceRandom,
    required this.secretKey,
  });

  final Uint8List clientPublicKey;
  final Uint8List publicKey;
  final Uint8List deviceRandom;
  final SecretKey secretKey;
  final DartAesCtr _aesCtr = const DartAesCtr.with256bits(
    macAlgorithm: MacAlgorithm.empty,
    counterBits: 128,
  );
  int _keyStreamIndex = 0;

  static Future<_Security1Device> create({
    required Uint8List clientPublicKey,
    required String pop,
  }) async {
    final x25519 = X25519();
    final keyPair = await x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final shared = await x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        clientPublicKey,
        type: KeyPairType.x25519,
      ),
    );
    final sharedBytes = Uint8List.fromList(await shared.extractBytes());
    if (pop.isNotEmpty) {
      final popHash = await Sha256().hash(pop.codeUnits);
      for (var i = 0; i < sharedBytes.length; i++) {
        sharedBytes[i] ^= popHash.bytes[i];
      }
    }

    return _Security1Device._(
      clientPublicKey: clientPublicKey,
      publicKey: Uint8List.fromList(publicKey.bytes),
      deviceRandom: Uint8List.fromList(List<int>.generate(16, (i) => i)),
      secretKey: SecretKey(sharedBytes),
    );
  }

  Uint8List command0Response() {
    return Uint8List.fromList(
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Response0,
          sr0: pb.SessionResp0(
            status: pb.Status.Success,
            devicePubkey: publicKey,
            deviceRandom: deviceRandom,
          ),
        ),
      ).writeToBuffer(),
    );
  }

  Future<Uint8List> command1Response(Uint8List encryptedVerifyData) async {
    final verify = await decrypt(encryptedVerifyData);
    expect(verify, publicKey);

    final encryptedHostPublicKey = await encrypt(clientPublicKey);

    return Uint8List.fromList(
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Response1,
          sr1: pb.SessionResp1(
            status: pb.Status.Success,
            deviceVerifyData: encryptedHostPublicKey,
          ),
        ),
      ).writeToBuffer(),
    );
  }

  Future<Uint8List> encrypt(Uint8List data) => _crypt(data);

  Future<Uint8List> decrypt(Uint8List data) => _crypt(data);

  Future<Uint8List> _crypt(Uint8List data) async {
    final box = await _aesCtr.encrypt(
      data,
      secretKey: secretKey,
      nonce: deviceRandom,
      keyStreamIndex: _keyStreamIndex,
    );
    _keyStreamIndex += data.length;
    return Uint8List.fromList(box.cipherText);
  }
}
