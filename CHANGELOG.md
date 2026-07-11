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
