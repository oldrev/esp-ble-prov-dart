/// Exception thrown when provisioning transport, protocol, or security work
/// fails.
class ProvisionerError implements Exception {
  /// Creates a provisioning error with a human-readable [message].
  const ProvisionerError(this.message);

  /// Details about the failed provisioning operation.
  final String message;

  @override
  String toString() => 'ProvisionerError: $message';
}
