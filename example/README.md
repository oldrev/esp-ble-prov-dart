# ESP BLE Provisioning Example

This Flutter app is intended for hands-on provisioning tests with an ESP device.

Before running it, configure the target platform permissions required by
`universal_ble`:

- Android: Bluetooth scan/connect permissions in `AndroidManifest.xml`.
- iOS/macOS: Bluetooth usage descriptions in `Info.plist`.
- Windows: Bluetooth capability when packaging.
- Linux: BlueZ access.
- Web: run in Chrome or Edge with Web Bluetooth support.

The example uses ESP-IDF's current built-in BLE provisioning service UUID,
1775244d-6b43-439b-877c-060f2d9bed07. The older 0000ffff-0000-1000-8000-00805f9b34fb
service UUID is not supported by this example. Endpoint names are read from GATT
descriptors on Web when available, with default UUID derivation as a fallback.
Custom endpoints can still be registered explicitly.

Run on Web:

```bash
flutter run -d edge
```

Web Bluetooth requires a secure context. Flutter's local dev server uses
`localhost`, which is allowed by browsers. For hosted builds, serve the app over
HTTPS. Web Bluetooth does not perform background scans: the example's
"Authorize Device" button opens the browser device chooser, then connects to the
single device selected by the user.
