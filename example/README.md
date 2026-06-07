# bluez_obex_native examples

These examples demonstrate the main OBEX workflows for the `bluez_obex_native` package.

Run them from the package root. You can test them against a physical BlueZ OBEX device.

For CLI runs, the package resolves the native library in this order:

1. `BLUEZ_OBEX_LIB=/absolute/path/to/libbluez_obex_native.so`
2. executable-adjacent library paths
3. local build outputs such as `build/native/libbluez_obex_native.so`
4. the system loader path, `libbluez_obex_native.so`

## Flutter Phone Message

`example/flutter_phone_message` is a dedicated Flutter Linux app mirroring the sibling `flutter_ble_scanner` and `flutter_ble_audio` examples.

```sh
cd example/flutter_phone_message
flutter run -d linux
```

The app lets you connect to an OBEX endpoint, sync contacts to a `.vcf` file, list inbox messages, and download selected messages.

## Phonebook Sync

Create a PBAP session and download contacts to a local `.vcf` file:

```sh
dart run example/phonebook_sync.dart --help
dart run example/phonebook_sync.dart AA:BB:CC:DD:EE:FF
dart run example/phonebook_sync.dart AA:BB:CC:DD:EE:FF --limit 10
```

## Message Inbox

Create a MAP session, list messages, and download them to a `.bmsg` file:

```sh
dart run example/message_inbox.dart --help
dart run example/message_inbox.dart AA:BB:CC:DD:EE:FF list
dart run example/message_inbox.dart AA:BB:CC:DD:EE:FF list --limit 10
dart run example/message_inbox.dart AA:BB:CC:DD:EE:FF download /org/bluez/obex/client/session0/message0
```
