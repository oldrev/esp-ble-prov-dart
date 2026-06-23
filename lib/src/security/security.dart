import 'dart:typed_data';

abstract class Security {
  const Security();

  Future<Uint8List> setup0Request();
  Future<void> setup0Response(Uint8List response);

  Future<Uint8List?> setup1Request() async => null;
  Future<void> setup1Response(Uint8List response) async {}

  Future<Uint8List> encrypt(Uint8List data);
  Future<Uint8List> decrypt(Uint8List data);
}
