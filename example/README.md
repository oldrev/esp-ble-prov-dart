# ESP BLE Provisioning Example

This Flutter app is intended for hands-on provisioning tests with an ESP device.

Before running it, configure the target platform permissions required by
`universal_ble`:

- Android: Bluetooth scan/connect permissions in `AndroidManifest.xml`.
- iOS/macOS: Bluetooth usage descriptions in `Info.plist`.
- Windows: Bluetooth capability when packaging.
- Linux: BlueZ access.
- Web: run in Chrome or Edge with Web Bluetooth support.

The app uses Espressif's default provisioning service UUID and derives the built-in
endpoint characteristic UUIDs automatically. Custom endpoints can still be
registered in code when your firmware exposes additional protocomm endpoints.

Run on Web:

```bash
flutter run -d edge
```

Web Bluetooth requires a secure context. Flutter's local dev server uses
`localhost`, which is allowed by browsers. For hosted builds, serve the app over
HTTPS.
