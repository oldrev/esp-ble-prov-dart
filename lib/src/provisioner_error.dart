/// Stable categories for provisioning failures.
enum ProvisionerErrorCode {
  unknown,
  cancelled,
  disposed,
  permissionDenied,
  deviceNotFound,
  connectionFailed,
  connectionLost,
  endpointNotFound,
  timeout,
  protocolViolation,
  securityFailed,
  sessionInvalidated,
  wifiConnectionFailed,
  unsupported,
}

/// Exception thrown when provisioning transport, protocol, or security work
/// fails.
class ProvisionerError implements Exception {
  const ProvisionerError(
    this.message, {
    this.code = ProvisionerErrorCode.unknown,
    this.operation,
    this.endpoint,
    this.cause,
    this.causeStackTrace,
    this.isRetryable = false,
  });

  final String message;
  final ProvisionerErrorCode code;
  final String? operation;
  final String? endpoint;
  final Object? cause;
  final StackTrace? causeStackTrace;
  final bool isRetryable;

  @override
  String toString() {
    final context = [
      if (operation != null) 'operation=$operation',
      if (endpoint != null) 'endpoint=$endpoint',
      'code=${code.name}',
    ].join(', ');
    return 'ProvisionerError($context): $message';
  }
}
