# flutter_phone_message

Flutter Linux app demonstrating phone contacts and messages over
`bluez_obex_native`.

The app mirrors the sibling example apps in this workspace:

* `bluez_native/example/flutter_ble_scanner`
* `bluez_media_native/example/flutter_ble_audio`

It supports two modes:

* **Simulated endpoint**: default, no Bluetooth hardware required.
* **Physical BlueZ OBEX**: connect the phone in system Bluetooth settings,
  disable the toggle, refresh BlueZ devices, choose a phone, then sync contacts
  or list the inbox. The app creates the needed OBEX session for each action.

Run:

```sh
flutter run -d linux
```

Build:

```sh
flutter build linux
```
