import 'dart:typed_data';

import '../provisioner_error.dart';
import 'security.dart';

/// ESP provisioning security scheme 2 placeholder.
///
/// Security2 requires SRP6a and AES-GCM support. This class exposes the
/// expected constructor shape but throws [ProvisionerError] for all operations
/// until the implementation is completed.
class Security2 extends Security {
  /// Creates a Security2 configuration placeholder.
  Security2({required this.password, this.username = 'wifiprov'});

  /// SRP username configured on the ESP device.
  final String username;

  /// SRP password configured on the ESP device.
  final String password;

  Never _unsupported() =>
      throw const ProvisionerError(
        'Security2 is not implemented yet. Use Security0 for open provisioning '
        'tests or implement SRP6a/AES-GCM before using Security2 devices.',
      );

  @override
  Future<Uint8List> setup0Request() async => _unsupported();

  @override
  Future<void> setup0Response(Uint8List response) async => _unsupported();

  @override
  Future<Uint8List> encrypt(Uint8List data) async => _unsupported();

  @override
  Future<Uint8List> decrypt(Uint8List data) async => _unsupported();
}
