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
}
