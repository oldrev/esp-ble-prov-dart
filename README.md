## 0.6.1

- Fixed the CI lint warning caused by an unawaited `Future` inside a `try` block.
- Kept the existing provisioning and BLE transport behavior unchanged while satisfying analyzer checks.

## 0.6.0

- Fixed Web Bluetooth writes for `Uint8List` views with non-zero offsets.
- Serialized complete scan and credential provisioning workflows atomically.
- Added connection-generation invalidation and idempotent `dispose()` cleanup.
- Invalidated Security1 sessions after uncertain transport failures.
- Added atomic custom endpoint request/response exchange API.
- Removed payload bytes from default logs and error messages.
- Improved Web Bluetooth cache, listener, and stream cleanup.
- Added descriptor-first endpoint mapping with explicit and derived fallbacks.
- Added `authorizeDevice()` and explicit Web Bluetooth chooser semantics.
- Added structured provisioning error codes with cause and operation context.
- Added cooperative cancellation for discovery, connection, scan, and credential workflows.
- Replaced public generated protobuf enums with stable package-owned Wi-Fi enums.
- Added defensive byte-array models, value equality, and redacted credential output.
- Added validated `ProvisioningTimeouts` and monotonic polling deadlines.
- Made Web transport disposal idempotent and remove disconnect listeners eagerly.
- Expanded hardware-independent tests to cover protocol validation, boundaries,
  deterministic concurrency, fault injection, and Web chooser lifecycle.

## 0.5.0

- Published by mistake. No intended release changes.

## 0.4.0

- Added serialized provisioning exchanges to keep Security1 AES-CTR state aligned.
- Added response read retry and timeout handling for BLE endpoint exchanges.
- Relaxed connect-time endpoint validation and validate optional endpoints on use.
- Added detailed Wi-Fi scan status and wait for scan completion before reading results.
- Added paged Wi-Fi scan result reads to reduce BLE response size and timeout risk.
- Changed `scan()` to use named parameters for scan options, timeout, poll interval, and page size.
- Added stricter provisioning response type/payload validation.
- Added Wi-Fi configuration and scan option validation before sending requests.
- Added connection-state handling for transport disconnect cleanup.

## 0.2.0

- Rename constants.

## 0.1.1

- Updated package information.

## 0.1.0

- Initial release of the Dart/Flutter ESP BLE provisioning client.
- Added BLE device discovery, connection, and ESP provisioning endpoint support.
- Added Security0 and Security1 session support.
- Added Wi-Fi scan, configuration, apply, and status polling APIs.
- Added custom endpoint read/write helpers.
