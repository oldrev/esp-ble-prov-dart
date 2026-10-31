  Future<Uint8List> readValueFromEndpoint(String endpointName) async {
    return await _runExclusive(() async {
      try {
        final value = await _readEndpoint(endpointName);
        return await security.decrypt(value);
      } catch (error) {
        security.invalidate(error);
        rethrow;
      }
    });
  }
