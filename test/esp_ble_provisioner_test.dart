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

  test('Security0 rejects malformed and failed responses', () async {
    const security = Security0();
    await expectLater(
      security.setup0Response(Uint8List.fromList([0xff, 0xff])),
      throwsA(anything),
    );
    final failed =
        pb.SessionData(
          secVer: pb.SecSchemeVersion.SecScheme0,
          sec0: pb.Sec0Payload(
            msg: pb.Sec0MsgType.S0_Session_Response,
            sr: pb.S0SessionResp(status: pb.Status.InternalError),
          ),
        ).writeToBuffer();
    await expectLater(
      security.setup0Response(Uint8List.fromList(failed)),
      throwsA(isA<ProvisionerError>()),
    );
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
    expect(networks.single.auth, WiFiAuthMode.wpa2Psk);
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
      WiFiConfig(ssid: 'Lab WiFi', passphrase: 'secret'),
    );

    expect(status.state, WiFiStationState.connected);
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
    expect(
      deriveProtocommCharacteristicUuid(serviceUuid.toUpperCase(), 0xff51),
      endpoints[provSessionEndpoint],
    );
  });

  test('derives custom endpoint UUIDs from ESP-IDF custom endpoint index', () {
    expect(espProvisioningCustomEndpointShortUuid(0), 0xff54);
    expect(espProvisioningCustomEndpointShortUuid(1), 0xff55);
    expect(
      deriveEspProvisioningCustomEndpointUuid(serviceUuid, 0),
      '0000ff54-0000-1000-8000-00805f9b34fb',
    );
  });

  test('uses descriptor endpoint mappings before UUID derivation', () async {
    const descriptorEndpoints = {
      provSessionEndpoint: '0000aa01-0000-1000-8000-00805f9b34fb',
      provConfigEndpoint: '0000aa02-0000-1000-8000-00805f9b34fb',
      provScanEndpoint: '0000aa03-0000-1000-8000-00805f9b34fb',
      'device-info': '0000aa04-0000-1000-8000-00805f9b34fb',
    };
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: descriptorEndpoints,
      descriptorMappings: descriptorEndpoints,
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      transport: transport,
      security: const Security0(),
    );

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    expect(
      provisioner.endpointUuids[provSessionEndpoint],
      descriptorEndpoints[provSessionEndpoint],
    );
    expect(
      provisioner.endpointUuids['device-info'],
      descriptorEndpoints['device-info'],
    );
    expect(
      provisioner.endpointUuidSources[provSessionEndpoint],
      EndpointUuidSource.descriptor,
    );
    expect(
      provisioner.endpointUuidSources['device-info'],
      EndpointUuidSource.descriptor,
    );
  });

  test('explicit endpoint mappings override descriptors', () async {
    const explicitSession = '0000bb01-0000-1000-8000-00805f9b34fb';
    const descriptorSession = '0000aa01-0000-1000-8000-00805f9b34fb';
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        provSessionEndpoint: explicitSession,
        provConfigEndpoint: endpoints[provConfigEndpoint]!,
        'descriptor-session': descriptorSession,
      },
      descriptorMappings: const {provSessionEndpoint: descriptorSession},
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      endpointUuids: const {provSessionEndpoint: explicitSession},
      transport: transport,
      security: const Security0(),
    );

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    expect(provisioner.endpointUuids[provSessionEndpoint], explicitSession);
    expect(
      provisioner.endpointUuidSources[provSessionEndpoint],
      EndpointUuidSource.explicit,
    );
    expect(
      provisioner.endpointUuidSources[provConfigEndpoint],
      EndpointUuidSource.derived,
    );
  });

  test(
    'chooser platforms authorize one device without timed scanning',
    () async {
      final transport = _ChooserFakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
      );
      final provisioner = EspBleProvisioner(
        serviceUuid: serviceUuid,
        deviceNamePrefix: 'BOPROV_',
        transport: transport,
      );
      final stopwatch = Stopwatch()..start();

      final device = await provisioner.authorizeDevice();
      await provisioner.connect(device: device);

      stopwatch.stop();
      expect(device.id, 'device-1');
      expect(provisioner.isConnected, isTrue);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
      expect(provisioner.usesDeviceChooser, isTrue);
      expect(provisioner.supportsDescriptorEndpointDiscovery, isTrue);
    },
  );

  test(
    'chooser scan compatibility API returns one authorized device',
    () async {
      final provisioner = EspBleProvisioner(
        serviceUuid: serviceUuid,
        deviceNamePrefix: 'BOPROV_',
        transport: _ChooserFakeTransport(
          serviceUuid: serviceUuid,
          endpoints: endpoints,
        ),
      );

      final devices = await provisioner.scanDevices(
        duration: const Duration(seconds: 30),
      );

      expect(devices, hasLength(1));
    },
  );

  test('chooser platforms require authorization before connect', () {
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      transport: _ChooserFakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
      ),
    );

    expect(
      () => provisioner.connect(),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.message,
          'message',
          contains('authorizeDevice'),
        ),
      ),
    );
  });

  test(
    'chooser cancellation and browser failures are classified and cleaned',
    () async {
      final cases = <(String, ProvisionerErrorCode)>[
        (
          'NotFoundError: user cancelled chooser',
          ProvisionerErrorCode.cancelled,
        ),
        (
          'NotAllowedError: permission denied',
          ProvisionerErrorCode.permissionDenied,
        ),
        (
          'SecurityError: insecure context',
          ProvisionerErrorCode.permissionDenied,
        ),
        ('NotSupportedError: unavailable', ProvisionerErrorCode.unsupported),
      ];
      for (final testCase in cases) {
        final transport = _ChooserFakeTransport(
          serviceUuid: serviceUuid,
          endpoints: endpoints,
          startScanError: StateError(testCase.$1),
        );
        final provisioner = EspBleProvisioner(
          serviceUuid: serviceUuid,
          deviceNamePrefix: 'BOPROV_',
          transport: transport,
        );

        await expectLater(
          provisioner.authorizeDevice(),
          throwsA(
            isA<ProvisionerError>().having(
              (error) => error.code,
              'code',
              testCase.$2,
            ),
          ),
        );
        expect(transport.hasScanListener, isFalse);
        await provisioner.dispose();
      }
    },
  );

  test('repeated chooser connections release connection streams', () async {
    final transport = _ChooserFakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    for (var round = 0; round < 3; round++) {
      final provisioner = EspBleProvisioner(
        serviceUuid: serviceUuid,
        deviceNamePrefix: 'BOPROV_',
        transport: transport,
      );
      final device = await provisioner.authorizeDevice();
      await provisioner.connect(device: device);
      await provisioner.disconnect();
      expect(transport.connectionControllerCount, 0);
    }
    await transport.dispose();
  });

  test('native scan transports reject authorizeDevice', () {
    final provisioner = _provisioner(
      _FakeTransport(serviceUuid: serviceUuid, endpoints: endpoints),
      serviceUuid,
      endpoints,
    );

    expect(
      () => provisioner.authorizeDevice(),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.code,
          'code',
          ProvisionerErrorCode.unsupported,
        ),
      ),
    );
    expect(provisioner.usesDeviceChooser, isFalse);
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

  test(
    'Security1 can establish a fresh session after a previous handshake',
    () async {
      final host = Security1(pop: 'repeat-pop');
      for (var round = 0; round < 2; round++) {
        final command0 = pb.SessionData.fromBuffer(await host.setup0Request());
        final device = await _Security1Device.create(
          clientPublicKey: Uint8List.fromList(command0.sec1.sc0.clientPubkey),
          pop: 'repeat-pop',
        );
        await host.setup0Response(device.command0Response());
        final command1 = pb.SessionData.fromBuffer(
          (await host.setup1Request())!,
        );
        await host.setup1Response(
          await device.command1Response(
            Uint8List.fromList(command1.sec1.sc1.clientVerifyData),
          ),
        );
        expect(host.isEstablished, isTrue);
      }
    },
  );

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

  test('Security1 rejects use after the session is invalidated', () async {
    final host = Security1();
    final command0 = pb.SessionData.fromBuffer(await host.setup0Request());
    final device = await _Security1Device.create(
      clientPublicKey: Uint8List.fromList(command0.sec1.sc0.clientPubkey),
      pop: '',
    );
    await host.setup0Response(device.command0Response());
    final command1 = pb.SessionData.fromBuffer((await host.setup1Request())!);
    await host.setup1Response(
      await device.command1Response(
        Uint8List.fromList(command1.sec1.sc1.clientVerifyData),
      ),
    );

    host.invalidate(StateError('uncertain BLE write'));

    await expectLater(
      host.encrypt(Uint8List.fromList([1, 2, 3])),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.message,
          'message',
          contains('session is invalid'),
        ),
      ),
    );
  });

  test('Security1 rejects application data before proof completes', () async {
    final host = Security1();
    final command0 = pb.SessionData.fromBuffer(await host.setup0Request());
    final device = await _Security1Device.create(
      clientPublicKey: Uint8List.fromList(command0.sec1.sc0.clientPubkey),
      pop: '',
    );
    await host.setup0Response(device.command0Response());

    await expectLater(
      host.encrypt(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<ProvisionerError>()),
    );
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

  test(
    'throws when an overridden endpoint UUID is used but not found',
    () async {
      final transport = _FakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
      );
      final provisioner = EspBleProvisioner(
        serviceUuid: serviceUuid,
        endpointUuids: {
          provScanEndpoint: '0000aaaa-0000-1000-8000-00805f9b34fb',
        },
        transport: transport,
      );

      await provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      );

      await expectLater(
        provisioner.startScan(),
        throwsA(
          isA<ProvisionerError>().having(
            (error) => error.message,
            'message',
            contains('prov-scan'),
          ),
        ),
      );
    },
  );

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

  test('clears connection state when transport reports disconnect', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    expect(provisioner.isConnected, isTrue);

    transport.emitConnection('device-1', false);
    await Future<void>.delayed(Duration.zero);

    expect(provisioner.isConnected, isFalse);
  });

  test('waits for Wi-Fi scan to finish before reading results', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      delayedScanFinish: true,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    final networks = await provisioner.scan();

    expect(networks, hasLength(1));
    expect(transport.scanStatusReads, 2);
    expect(transport.scanResultReads, 1);
  });

  test('reads Wi-Fi scan results in pages', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      networkCount: 9,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    final networks = await provisioner.scan(pageSize: 4);

    expect(networks, hasLength(9));
    expect(transport.scanResultRequests, ['0:4', '4:4', '8:1']);
  });

  test('rejects invalid Wi-Fi scan page size', () {
    final provisioner = _provisioner(
      _FakeTransport(serviceUuid: serviceUuid, endpoints: endpoints),
      serviceUuid,
      endpoints,
    );

    expect(() => provisioner.scan(pageSize: 0), throwsArgumentError);
  });

  test('rejects invalid Wi-Fi config before writing credentials', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    await expectLater(
      provisioner.setWiFiConfig(
        WiFiConfig(ssid: List.filled(33, 'x').join(), passphrase: 'secret'),
      ),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.message,
          'message',
          contains('SSID'),
        ),
      ),
    );

    expect(transport.decodedConfigWrites, isEmpty);
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

    await provisioner.exchangeValueToEndpoint(
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

    await provisioner.exchangeValueToEndpoint(
      'device-id',
      Uint8List.fromList([10, 20, 30]),
    );

    expect(
      transport.writes.last.characteristic,
      '0000ff54-0000-1000-8000-00805f9b34fb',
    );
  });

  test('exchanges custom endpoint values atomically', () async {
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

    final response = await provisioner.exchangeValueToEndpoint(
      'device-id',
      Uint8List.fromList([10, 20, 30]),
    );

    expect(response, [10, 20, 30]);
  });

  test('keeps the complete credential flow atomic', () async {
    final writeStarted = Completer<void>();
    final writeGate = Completer<void>();
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      firstConfigWriteStarted: writeStarted,
      firstConfigWriteGate: writeGate,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    final credentials = provisioner.sendCredentials(
      WiFiConfig(ssid: 'Lab WiFi', passphrase: 'secret'),
    );
    await writeStarted.future;
    final scan = provisioner.startScan();
    writeGate.complete();

    await credentials;
    await scan;
    expect(transport.operationLog, [
      'config:set',
      'config:apply',
      'config:status',
      'scan:start',
    ]);
  });

  test('disconnect invalidates in-flight and queued operations', () async {
    final writeStarted = Completer<void>();
    final writeGate = Completer<void>();
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      firstConfigWriteStarted: writeStarted,
      firstConfigWriteGate: writeGate,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    final credentials = provisioner.sendCredentials(
      WiFiConfig(ssid: 'Lab WiFi', passphrase: 'secret'),
    );
    await writeStarted.future;
    final queuedScan = provisioner.startScan();
    final disconnect = provisioner.disconnect();
    writeGate.complete();

    await expectLater(credentials, throwsA(isA<ProvisionerError>()));
    await expectLater(queuedScan, throwsA(isA<ProvisionerError>()));
    await disconnect;
    expect(provisioner.isConnected, isFalse);
    expect(transport.operationLog, ['config:set']);
  });

  test(
    'a queued old-connection task never runs on a reconnected device',
    () async {
      final writeStarted = Completer<void>();
      final writeGate = Completer<void>();
      final transport = _FakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
        firstConfigWriteStarted: writeStarted,
        firstConfigWriteGate: writeGate,
      );
      final provisioner = _provisioner(transport, serviceUuid, endpoints);
      await provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_ONE'),
      );
      final active = provisioner.sendCredentials(
        WiFiConfig(ssid: 'Lab WiFi', passphrase: 'secret'),
      );
      await writeStarted.future;
      final stale = provisioner.startScan();
      final disconnect = provisioner.disconnect();
      writeGate.complete();
      await expectLater(active, throwsA(isA<ProvisionerError>()));
      await expectLater(stale, throwsA(isA<ProvisionerError>()));
      await disconnect;

      await provisioner.connect(
        device: const EspBleDevice(id: 'device-2', name: 'BOPROV_TWO'),
      );
      await provisioner.startScan();

      expect(transport.writeDeviceIds.last, 'device-2');
      expect(transport.operationLog, ['config:set', 'scan:start']);
    },
  );

  test('serializes two complete credential workflows', () async {
    final writeStarted = Completer<void>();
    final writeGate = Completer<void>();
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      firstConfigWriteStarted: writeStarted,
      firstConfigWriteGate: writeGate,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    final first = provisioner.sendCredentials(WiFiConfig(ssid: 'first'));
    await writeStarted.future;
    final second = provisioner.sendCredentials(WiFiConfig(ssid: 'second'));
    writeGate.complete();
    await Future.wait([first, second]);

    expect(transport.operationLog, [
      'config:set',
      'config:apply',
      'config:status',
      'config:set',
      'config:apply',
      'config:status',
    ]);
  });

  test('handles remote and active disconnect racing', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    transport.emitConnection('device-1', false);
    await provisioner.disconnect();

    expect(provisioner.isConnected, isFalse);
    expect(transport.disconnects, lessThanOrEqualTo(1));
  });

  test('times out after a successful write followed by empty reads', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      alwaysEmptyReads: true,
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      transport: transport,
      security: const Security0(),
      responseDelay: Duration.zero,
      responseTimeout: const Duration(milliseconds: 30),
      readRetryInterval: const Duration(milliseconds: 5),
    );
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    await expectLater(
      provisioner.startScan(),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.code,
          'code',
          ProvisionerErrorCode.timeout,
        ),
      ),
    );
    expect(transport.writes, hasLength(1));
  });

  test(
    'disconnects deterministically while a response read is suspended',
    () async {
      final readStarted = Completer<void>();
      final readGate = Completer<void>();
      final transport = _FakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
        readStarted: readStarted,
        readGate: readGate,
      );
      final provisioner = _provisioner(transport, serviceUuid, endpoints);
      await provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      );

      final operation = provisioner.startScan();
      await readStarted.future;
      final disconnect = provisioner.disconnect();
      readGate.complete();

      await expectLater(
        operation,
        throwsA(
          isA<ProvisionerError>().having(
            (error) => error.code,
            'code',
            ProvisionerErrorCode.connectionLost,
          ),
        ),
      );
      await disconnect;
      expect(provisioner.isConnected, isFalse);
    },
  );

  test('cleans scan subscription when start and stop both fail', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      throwOnStartScan: true,
      throwOnStopScan: true,
    );
    final provisioner = EspBleProvisioner(
      deviceNamePrefix: 'BOPROV_',
      transport: transport,
    );

    await expectLater(
      provisioner.scanDevices(duration: const Duration(milliseconds: 1)),
      throwsA(isA<ProvisionerError>()),
    );
    expect(transport.hasScanListener, isFalse);
  });

  test(
    'cleans scan state when subscription cancellation itself fails',
    () async {
      final transport = _FakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
        throwOnScanCancel: true,
      );
      final provisioner = EspBleProvisioner(
        deviceNamePrefix: 'BOPROV_',
        transport: transport,
      );

      await expectLater(
        provisioner.scanDevices(duration: const Duration(milliseconds: 1)),
        throwsA(isA<ProvisionerError>()),
      );
      expect(transport.hasScanListener, isFalse);
    },
  );

  test('failed connection cleanup tolerates its own failures', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        provSessionEndpoint: '0000aa51-0000-1000-8000-00805f9b34fb',
        provConfigEndpoint: '0000aa52-0000-1000-8000-00805f9b34fb',
      },
      discoveredServiceUuid: '00001234-0000-1000-8000-00805f9b34fb',
      throwOnStopScanAfterFirst: true,
      throwOnDisconnect: true,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    await expectLater(
      provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      ),
      throwsA(isA<ProvisionerError>()),
    );
    expect(provisioner.isConnected, isFalse);
    expect(transport.stopScanCalls, greaterThanOrEqualTo(2));
  });

  test('classifies truncated and stale endpoint responses', () async {
    for (final forced in <Uint8List>[
      Uint8List.fromList([0x08]),
      Uint8List.fromList(
        pb.WiFiConfigPayload(
          msg: pb.WiFiConfigMsgType.TypeRespApplyConfig,
          respApplyConfig: pb.RespApplyConfig(status: pb.Status.Success),
        ).writeToBuffer(),
      ),
    ]) {
      final provisioner = EspBleProvisioner(
        serviceUuid: serviceUuid,
        transport: _FakeTransport(
          serviceUuid: serviceUuid,
          endpoints: endpoints,
          forcedRead: forced,
        ),
        security: const Security0(),
        responseDelay: Duration.zero,
      );
      await provisioner.connect(
        device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      );
      await expectLater(
        provisioner.startScan(),
        throwsA(
          isA<ProvisionerError>().having(
            (error) => error.code,
            'code',
            ProvisionerErrorCode.protocolViolation,
          ),
        ),
      );
      await provisioner.dispose();
    }
  });

  test('returns a large custom endpoint response without truncation', () async {
    final response = Uint8List.fromList(
      List<int>.generate(4096, (index) => index & 0xff),
    );
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: {
        ...endpoints,
        'large': '0000aaaa-0000-1000-8000-00805f9b34fb',
      },
      forcedRead: response,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    provisioner.registerEndpoint(
      'large',
      '0000aaaa-0000-1000-8000-00805f9b34fb',
    );

    final actual = await provisioner.exchangeValueToEndpoint(
      'large',
      Uint8List.fromList([1]),
    );
    expect(actual, response);
  });

  test('disconnect cancels an in-flight connection attempt', () async {
    final connectStarted = Completer<void>();
    final connectGate = Completer<void>();
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      connectStarted: connectStarted,
      connectGate: connectGate,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);

    final connecting = provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    await connectStarted.future;
    final disconnect = provisioner.disconnect();
    connectGate.complete();

    await expectLater(connecting, throwsA(isA<ProvisionerError>()));
    await disconnect;
    expect(provisioner.isConnected, isFalse);
  });

  test('cancellation token cancels an in-flight connection attempt', () async {
    final connectStarted = Completer<void>();
    final connectGate = Completer<void>();
    final token = ProvisioningCancellationToken();
    final provisioner = _provisioner(
      _FakeTransport(
        serviceUuid: serviceUuid,
        endpoints: endpoints,
        connectStarted: connectStarted,
        connectGate: connectGate,
      ),
      serviceUuid,
      endpoints,
    );

    final connecting = provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
      cancellationToken: token,
    );
    await connectStarted.future;
    token.cancel();
    connectGate.complete();

    await expectLater(
      connecting,
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.code,
          'code',
          ProvisionerErrorCode.cancelled,
        ),
      ),
    );
    expect(provisioner.isConnected, isFalse);
  });

  test('invalidates security after an uncertain transport failure', () async {
    final security = _TrackingSecurity();
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
      failNextWrite: true,
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      transport: transport,
      security: security,
    );
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    await expectLater(
      provisioner.startScan(),
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
    expect(security.invalidated, isTrue);
  });

  test('does not log payload bytes unless explicitly enabled', () async {
    final logs = <String>[];
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      transport: transport,
      security: const Security0(),
      onLog: logs.add,
    );
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );
    await provisioner.setWiFiConfig(
      WiFiConfig(ssid: 'Private SSID', passphrase: 'secret'),
    );

    final combined = logs.join('\n');
    expect(combined, isNot(contains('Private SSID')));
    expect(combined, isNot(contains('secret')));
    expect(combined, isNot(contains('73 65 63 72 65 74')));
    expect(combined, isNot(contains('Write payload')));
  });

  test('compacts BLE write views to their visible byte range', () {
    final backing = Uint8List.fromList([1, 2, 3, 4, 5]);
    final view = Uint8List.sublistView(backing, 1, 4);

    final compact = compactBleWriteValue(view);

    expect(compact, [2, 3, 4]);
    expect(compact.offsetInBytes, 0);
    expect(compact.buffer.lengthInBytes, 3);
  });

  test('dispose is idempotent and rejects later operations', () async {
    final transport = _FakeTransport(
      serviceUuid: serviceUuid,
      endpoints: endpoints,
    );
    final provisioner = _provisioner(transport, serviceUuid, endpoints);
    await provisioner.connect(
      device: const EspBleDevice(id: 'device-1', name: 'BOPROV_TEST'),
    );

    await provisioner.dispose();
    await provisioner.dispose();

    expect(transport.disposed, isTrue);
    expect(provisioner.isConnected, isFalse);
    expect(() => provisioner.startScan(), throwsA(isA<ProvisionerError>()));
  });

  test('cancels a timed device scan cooperatively', () async {
    final token = ProvisioningCancellationToken();
    final provisioner = EspBleProvisioner(
      serviceUuid: serviceUuid,
      deviceNamePrefix: 'BOPROV_',
      transport: _FakeTransport(serviceUuid: serviceUuid, endpoints: endpoints),
    );

    final scanning = provisioner.scanDevices(
      duration: const Duration(seconds: 30),
      cancellationToken: token,
    );
    token.cancel();

    await expectLater(
      scanning,
      throwsA(
        isA<ProvisionerError>().having(
          (error) => error.code,
          'code',
          ProvisionerErrorCode.cancelled,
        ),
      ),
    );
  });

  test('validates endpoint timeout configuration', () {
    expect(
      () => EspBleProvisioner(
        transport: _FakeTransport(
          serviceUuid: serviceUuid,
          endpoints: endpoints,
        ),
        timeouts: const ProvisioningTimeouts(responseTimeout: Duration.zero),
      ),
      throwsArgumentError,
    );
  });

  test('public Wi-Fi models are independent from protobuf enums', () {
    expect(WiFiAuthMode.fromProtocolValue(3), WiFiAuthMode.wpa2Psk);
    expect(WiFiAuthMode.fromProtocolValue(99), WiFiAuthMode.unknown);
    expect(
      WiFiStationState.fromProtocolValue(3),
      WiFiStationState.connectionFailed,
    );

    final sourceBssid = <int>[1, 2, 3, 4, 5, 6];
    final config = WiFiConfig(
      ssid: 'Lab',
      passphrase: 'top-secret',
      bssid: sourceBssid,
    );
    sourceBssid[0] = 99;
    expect(config.bssid, [1, 2, 3, 4, 5, 6]);
    expect(() => config.bssid![0] = 8, throwsUnsupportedError);
    expect(config.toString(), isNot(contains('top-secret')));
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

class _FakeTransport
    implements
        EspBleTransport,
        DisposableEspBleTransport,
        BleEndpointMappingTransport {
  _FakeTransport({
    required this.serviceUuid,
    required this.endpoints,
    String? discoveredServiceUuid,
    this.protoVersionResponseOnScan = false,
    this.delayedScanFinish = false,
    this.networkCount = 1,
    this.firstConfigWriteStarted,
    this.firstConfigWriteGate,
    this.failNextWrite = false,
    this.connectStarted,
    this.connectGate,
    this.descriptorMappings = const {},
    this.alwaysEmptyReads = false,
    this.forcedRead,
    this.throwOnStartScan = false,
    this.startScanError,
    this.throwOnStopScan = false,
    this.throwOnStopScanAfterFirst = false,
    this.throwOnDisconnect = false,
    this.readStarted,
    this.readGate,
    this.throwOnScanCancel = false,
  }) : discoveredServiceUuid = discoveredServiceUuid ?? serviceUuid {
    _scanController = StreamController<BleDevice>.broadcast();
  }

  final String serviceUuid;
  final String discoveredServiceUuid;
  final Map<String, String> endpoints;
  final bool protoVersionResponseOnScan;
  final bool delayedScanFinish;
  final int networkCount;
  final Completer<void>? firstConfigWriteStarted;
  final Completer<void>? firstConfigWriteGate;
  bool failNextWrite;
  final Completer<void>? connectStarted;
  final Completer<void>? connectGate;
  final Map<String, String> descriptorMappings;
  final bool alwaysEmptyReads;
  final Uint8List? forcedRead;
  final bool throwOnStartScan;
  final Object? startScanError;
  final bool throwOnStopScan;
  final bool throwOnStopScanAfterFirst;
  final bool throwOnDisconnect;
  final Completer<void>? readStarted;
  final Completer<void>? readGate;
  final bool throwOnScanCancel;
  late final StreamController<BleDevice> _scanController;
  final Map<String, StreamController<bool>> _connectionControllers = {};
  final List<_WriteRecord> writes = [];
  final List<pb.WiFiConfigPayload> decodedConfigWrites = [];
  final List<String> scanResultRequests = [];
  final List<String> operationLog = [];
  final List<String> writeDeviceIds = [];
  int disconnects = 0;
  int? requestedMtu;
  int scanStatusReads = 0;
  int scanResultReads = 0;
  int stopScanCalls = 0;
  bool disposed = false;

  bool get hasScanListener => _scanController.hasListener;
  int get connectionControllerCount => _connectionControllers.length;

  Uint8List _nextRead = Uint8List(0);
  bool _connected = false;

  @override
  Stream<BleDevice> get scanStream =>
      throwOnScanCancel
          ? _CancelFailingStream(_scanController.stream)
          : _scanController.stream;

  @override
  Stream<bool> connectionStream(String deviceId) {
    return _connectionControllers
        .putIfAbsent(deviceId, () => StreamController<bool>.broadcast())
        .stream;
  }

  void emitConnection(String deviceId, bool isConnected) {
    _connectionControllers[deviceId]?.add(isConnected);
  }

  @override
  Future<void> requestPermissions({
    bool withAndroidFineLocation = false,
  }) async {}

  @override
  Future<void> startScan({
    ScanFilter? scanFilter,
    PlatformConfig? platformConfig,
  }) async {
    if (startScanError != null) throw startScanError!;
    if (throwOnStartScan) throw StateError('simulated startScan failure');
    _scanController.add(BleDevice(deviceId: 'device-1', name: 'BOPROV_TEST'));
  }

  @override
  Future<void> stopScan() async {
    stopScanCalls++;
    if (throwOnStopScan || (throwOnStopScanAfterFirst && stopScanCalls > 1)) {
      throw StateError('simulated stopScan failure');
    }
  }

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    if (connectStarted?.isCompleted == false) connectStarted!.complete();
    await connectGate?.future;
    _connected = true;
    emitConnection(deviceId, true);
  }

  @override
  Future<void> disconnect(String deviceId, {Duration? timeout}) async {
    disconnects++;
    if (throwOnDisconnect) {
      throw StateError('simulated disconnect failure');
    }
    _connected = false;
    emitConnection(deviceId, false);
    final controller = _connectionControllers.remove(deviceId);
    await controller?.close();
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
  Future<Map<String, String>> readEndpointMappings(
    String deviceId,
    String serviceUuid,
  ) async => descriptorMappings;

  @override
  Future<Uint8List> read(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    Duration? timeout,
  }) async {
    if (readStarted?.isCompleted == false) readStarted!.complete();
    await readGate?.future;
    if (forcedRead != null) return Uint8List.fromList(forcedRead!);
    if (alwaysEmptyReads) return Uint8List(0);
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
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated uncertain BLE write failure');
    }
    writes.add(_WriteRecord(characteristic: characteristicUuid, value: value));
    writeDeviceIds.add(deviceId);

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
          operationLog.add('scan:start');
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanStart,
              status: pb.Status.Success,
              respScanStart: pb.RespScanStart(),
            ).writeToBuffer(),
          );
        case pb.WiFiScanMsgType.TypeCmdScanStatus:
          operationLog.add('scan:status');
          scanStatusReads++;
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanStatus,
              status: pb.Status.Success,
              respScanStatus: pb.RespScanStatus(
                scanFinished: !delayedScanFinish || scanStatusReads > 1,
                resultCount: networkCount,
              ),
            ).writeToBuffer(),
          );
        case pb.WiFiScanMsgType.TypeCmdScanResult:
          operationLog.add('scan:result');
          scanResultReads++;
          scanResultRequests.add(
            '${request.cmdScanResult.startIndex}:${request.cmdScanResult.count}',
          );
          final startIndex = request.cmdScanResult.startIndex;
          final count = request.cmdScanResult.count;
          final actualCount =
              startIndex >= networkCount
                  ? 0
                  : (networkCount - startIndex < count
                      ? networkCount - startIndex
                      : count);
          _nextRead = Uint8List.fromList(
            pb.WiFiScanPayload(
              msg: pb.WiFiScanMsgType.TypeRespScanResult,
              status: pb.Status.Success,
              respScanResult: pb.RespScanResult(
                entries: List.generate(actualCount, (offset) {
                  final index = startIndex + offset;
                  return pb.WiFiScanResult(
                    ssid:
                        (networkCount == 1
                                ? 'Lab WiFi'
                                : 'Lab WiFi ${index + 1}')
                            .codeUnits,
                    channel: 6,
                    rssi: -42 - index,
                    bssid: [1, 2, 3, 4, 5, 6],
                    auth: pb.WifiAuthMode.WPA2_PSK,
                  );
                }),
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
          operationLog.add('config:set');
          _nextRead = Uint8List.fromList(
            pb.WiFiConfigPayload(
              msg: pb.WiFiConfigMsgType.TypeRespSetConfig,
              respSetConfig: pb.RespSetConfig(status: pb.Status.Success),
            ).writeToBuffer(),
          );
        case pb.WiFiConfigMsgType.TypeCmdApplyConfig:
          operationLog.add('config:apply');
          _nextRead = Uint8List.fromList(
            pb.WiFiConfigPayload(
              msg: pb.WiFiConfigMsgType.TypeRespApplyConfig,
              respApplyConfig: pb.RespApplyConfig(status: pb.Status.Success),
            ).writeToBuffer(),
          );
        case pb.WiFiConfigMsgType.TypeCmdGetStatus:
          operationLog.add('config:status');
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
      if (request.msg == pb.WiFiConfigMsgType.TypeCmdSetConfig &&
          firstConfigWriteGate != null) {
        if (firstConfigWriteStarted?.isCompleted == false) {
          firstConfigWriteStarted!.complete();
        }
        await firstConfigWriteGate!.future;
      }
      return;
    }

    _nextRead = Uint8List.fromList(value);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _scanController.close();
    for (final controller in _connectionControllers.values) {
      await controller.close();
    }
    _connectionControllers.clear();
  }

  bool _same(String a, String b) =>
      BleUuidParser.string(a) == BleUuidParser.string(b);
}

class _CancelFailingStream<T> extends StreamView<T> {
  _CancelFailingStream(super.stream);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _CancelFailingSubscription(
      super.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      ),
    );
  }
}

class _CancelFailingSubscription<T> implements StreamSubscription<T> {
  _CancelFailingSubscription(this._delegate);
  final StreamSubscription<T> _delegate;

  @override
  Future<void> cancel() async {
    await _delegate.cancel();
    throw StateError('simulated scan subscription cancel failure');
  }

  @override
  void onData(void Function(T data)? handleData) =>
      _delegate.onData(handleData);
  @override
  void onError(Function? handleError) => _delegate.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _delegate.onDone(handleDone);
  @override
  void pause([Future<void>? resumeSignal]) => _delegate.pause(resumeSignal);
  @override
  void resume() => _delegate.resume();
  @override
  bool get isPaused => _delegate.isPaused;
  @override
  Future<E> asFuture<E>([E? futureValue]) => _delegate.asFuture(futureValue);
}

class _ChooserFakeTransport extends _FakeTransport
    implements BleDeviceChooserTransport {
  _ChooserFakeTransport({
    required super.serviceUuid,
    required super.endpoints,
    super.startScanError,
  });
}

class _TrackingSecurity extends Security0 {
  bool invalidated = false;

  @override
  void invalidate([Object? cause]) {
    invalidated = true;
  }
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
