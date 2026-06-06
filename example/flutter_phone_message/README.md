# flutter_phone_message

Flutter Linux app demonstrating phone contacts and messages over
`bluez_obex_native`.

The app mirrors the sibling example apps in this workspace:

* `bluez_native/example/flutter_ble_scanner`
* `bluez_media_native/example/flutter_ble_audio`

It supports two modes:

* **Simulated endpoint**: default, no Bluetooth hardware required.
* **Physical BlueZ OBEX**: disable the toggle, enter a paired phone address,
  and use `org.bluez.obex` on the session bus.

Run:

```sh
flutter run -d linux
```

Build:

```sh
flutter build linux
```

