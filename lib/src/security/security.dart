import 'dart:typed_data';

/// Base contract for ESP provisioning security schemes.
///
/// Implementations perform the protocomm session handshake and encrypt or
/// decrypt endpoint payloads after a provisioning session has been established.
abstract class Security {
  /// Creates a security scheme.
  const Security();

  /// Builds the first security setup request for the `prov-session` endpoint.
  Future<Uint8List> setup0Request();

  /// Processes the first security setup response from the device.
  Future<void> setup0Response(Uint8List response);

  /// Builds an optional second security setup request.
  ///
  /// Return `null` for one-step schemes.
  Future<Uint8List?> setup1Request() async => null;

  /// Processes the optional second security setup response.
  Future<void> setup1Response(Uint8List response) async {}

  /// Encrypts a plain provisioning endpoint payload.
  Future<Uint8List> encrypt(Uint8List data);

  /// Decrypts a provisioning endpoint response payload.
  Future<Uint8List> decrypt(Uint8List data);

  /// Clears connection-specific state before establishing a new session.
  ///
  /// Stateless or backwards-compatible custom schemes may keep the default
  /// no-op implementation.
  void reset() {}

  /// Marks the current session unusable after an uncertain transport failure.
  ///
  /// Stateful schemes should reject subsequent encryption and decryption until
  /// a new handshake starts.
  void invalidate([Object? cause]) {}
}
