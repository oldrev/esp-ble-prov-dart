class ProvisionerError implements Exception {
  const ProvisionerError(this.message);

  final String message;

  @override
  String toString() => 'ProvisionerError: $message';
}
