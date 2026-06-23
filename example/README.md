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
service UUID is not supported by this example. Endpoint characteristic UUIDs are
derived from the default service UUID automatically. Custom endpoints can still
be registered in code when your firmware exposes additional protocomm endpoints.

Run on Web:

```bash
flutter run -d edge
```

Web Bluetooth requires a secure context. Flutter's local dev server uses
`localhost`, which is allowed by browsers. For hosted builds, serve the app over
HTTPS.
