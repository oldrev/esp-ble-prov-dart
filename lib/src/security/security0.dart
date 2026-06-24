import 'dart:typed_data';

import '../proto/protos.dart' as pb;
import '../provisioner_error.dart';
import 'security.dart';

/// ESP provisioning security scheme 0.
///
/// This scheme performs no encryption and should only be used with devices
/// configured for open provisioning or for local tests.
class Security0 extends Security {
  /// Creates an unencrypted provisioning security scheme.
  const Security0();

  @override
  Future<Uint8List> setup0Request() async {
    final sessionData = pb.SessionData(
      secVer: pb.SecSchemeVersion.SecScheme0,
      sec0: pb.Sec0Payload(
        msg: pb.Sec0MsgType.S0_Session_Command,
        sc: pb.S0SessionCmd(),
      ),
    );
    return Uint8List.fromList(sessionData.writeToBuffer());
  }

  @override
  Future<void> setup0Response(Uint8List response) async {
    final sessionData = pb.SessionData.fromBuffer(response);
    if (!sessionData.hasSec0() || !sessionData.sec0.hasSr()) {
      throw const ProvisionerError('Invalid Security0 session response.');
    }

    final status = sessionData.sec0.sr.status;
    if (status != pb.Status.Success) {
      throw ProvisionerError('Security0 session failed: ${status.name}');
    }
  }

  @override
  Future<Uint8List> encrypt(Uint8List data) async => data;

  @override
  Future<Uint8List> decrypt(Uint8List data) async => data;
}
