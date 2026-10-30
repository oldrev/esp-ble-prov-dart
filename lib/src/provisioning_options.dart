import 'dart:async';

import 'provisioner_error.dart';

/// Endpoint-level timing defaults used by [EspBleProvisioner].
class ProvisioningTimeouts {
  const ProvisioningTimeouts({
    this.responseDelay = const Duration(milliseconds: 200),
    this.responseTimeout = const Duration(seconds: 15),
    this.readRetryInterval = const Duration(milliseconds: 100),
  });

  final Duration responseDelay;
  final Duration responseTimeout;
  final Duration readRetryInterval;

  void validate() {
    if (responseDelay < Duration.zero) {
      throw ArgumentError.value(responseDelay, 'responseDelay');
    }
    if (responseTimeout <= Duration.zero) {
      throw ArgumentError.value(responseTimeout, 'responseTimeout');
    }
    if (readRetryInterval <= Duration.zero) {
      throw ArgumentError.value(readRetryInterval, 'readRetryInterval');
    }
  }
}

/// Cooperative cancellation signal for scans and provisioning workflows.
class ProvisioningCancellationToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled([String? operation]) {
    if (!isCancelled) return;
    throw ProvisionerError(
      'Provisioning operation was cancelled.',
      code: ProvisionerErrorCode.cancelled,
      operation: operation,
    );
  }
}
