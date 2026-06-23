import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:cryptography/cryptography.dart';

import '../proto/protos.dart' as pb;
import '../provisioner_error.dart';
import 'security.dart';

class Security1 extends Security {
  Security1({this.pop = ''});

  final String pop;

  final X25519 _x25519 = X25519();
  final DartAesCtr _aesCtr = const DartAesCtr.with256bits(
    macAlgorithm: MacAlgorithm.empty,
    counterBits: 128,
  );

  SimpleKeyPair? _keyPair;
  Uint8List? _publicKey;
  Uint8List? _devicePublicKey;
  Uint8List? _deviceRandom;
  SecretKey? _secretKey;
  int _keyStreamIndex = 0;

  @override
  Future<Uint8List> setup0Request() async {
    _keyPair = await _x25519.newKeyPair();
    final publicKey = await _keyPair!.extractPublicKey();
    _publicKey = Uint8List.fromList(publicKey.bytes);

    return Uint8List.fromList(
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Command0,
          sc0: pb.SessionCmd0(clientPubkey: _publicKey),
        ),
      ).writeToBuffer(),
    );
  }

  @override
  Future<void> setup0Response(Uint8List response) async {
    final keyPair = _keyPair;
    if (keyPair == null) {
      throw const ProvisionerError('Call setup0Request before setup0Response.');
    }

    final sessionData = pb.SessionData.fromBuffer(response);
    if (!sessionData.hasSec1() || !sessionData.sec1.hasSr0()) {
      throw const ProvisionerError('Invalid Security1 command0 response.');
    }

    final sr0 = sessionData.sec1.sr0;
    if (sr0.status != pb.Status.Success) {
      throw ProvisionerError('Security1 command0 failed: ${sr0.status.name}');
    }
    if (!sr0.hasDevicePubkey() || !sr0.hasDeviceRandom()) {
      throw const ProvisionerError(
        'Security1 response missing device key or random.',
      );
    }

    _devicePublicKey = Uint8List.fromList(sr0.devicePubkey);
    _deviceRandom = Uint8List.fromList(sr0.deviceRandom);

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        _devicePublicKey!,
        type: KeyPairType.x25519,
      ),
    );
    final sharedBytes = Uint8List.fromList(await sharedSecret.extractBytes());

    if (pop.isNotEmpty) {
      final popHash = await Sha256().hash(utf8.encode(pop));
      for (var i = 0; i < sharedBytes.length; i++) {
        sharedBytes[i] ^= popHash.bytes[i];
      }
    }

    _secretKey = SecretKey(sharedBytes);
    _keyStreamIndex = 0;
  }

  @override
  Future<Uint8List?> setup1Request() async {
    final devicePublicKey = _devicePublicKey;
    if (devicePublicKey == null) {
      throw const ProvisionerError('Security1 command0 is not complete.');
    }

    final encryptedDeviceKey = await _crypt(devicePublicKey);
    return Uint8List.fromList(
      pb.SessionData(
        secVer: pb.SecSchemeVersion.SecScheme1,
        sec1: pb.Sec1Payload(
          msg: pb.Sec1MsgType.Session_Command1,
          sc1: pb.SessionCmd1(clientVerifyData: encryptedDeviceKey),
        ),
      ).writeToBuffer(),
    );
  }

  @override
  Future<void> setup1Response(Uint8List response) async {
    final publicKey = _publicKey;
    if (publicKey == null) {
      throw const ProvisionerError('Security1 local public key is missing.');
    }

    final sessionData = pb.SessionData.fromBuffer(response);
    if (!sessionData.hasSec1() || !sessionData.sec1.hasSr1()) {
      throw const ProvisionerError('Invalid Security1 command1 response.');
    }

    final sr1 = sessionData.sec1.sr1;
    if (sr1.status != pb.Status.Success) {
      throw ProvisionerError('Security1 command1 failed: ${sr1.status.name}');
    }
    if (!sr1.hasDeviceVerifyData()) {
      throw const ProvisionerError('Security1 response missing verify data.');
    }

    final decrypted = await _crypt(Uint8List.fromList(sr1.deviceVerifyData));
    if (!_constantTimeEquals(decrypted, publicKey)) {
      throw const ProvisionerError('Security1 device verification failed.');
    }
  }

  @override
  Future<Uint8List> encrypt(Uint8List data) => _crypt(data);

  @override
  Future<Uint8List> decrypt(Uint8List data) => _crypt(data);

  Future<Uint8List> _crypt(Uint8List data) async {
    final secretKey = _secretKey;
    final nonce = _deviceRandom;
    if (secretKey == null || nonce == null) {
      throw const ProvisionerError('Security1 session is not established.');
    }

    final box = await _aesCtr.encrypt(
      data,
      secretKey: secretKey,
      nonce: nonce,
      keyStreamIndex: _keyStreamIndex,
    );
    _keyStreamIndex += data.length;
    return Uint8List.fromList(box.cipherText);
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
