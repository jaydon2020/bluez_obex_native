# bluez_obex_native_example

Example Flutter app for the `bluez_obex_native` package.

The app demonstrates the main OBEX workflows:

* Connect to a simulated endpoint or a physical BlueZ OBEX device.
* Create a PBAP/MAP session for a Bluetooth address.
* Sync contacts to a local `.vcf` file.
* List inbox messages.
* Download a selected message to a local `.bmsg` file.

Run on Linux:

```sh
flutter run -d linux
```

Leave **Simulated endpoint** enabled for local development without Bluetooth
hardware. Disable it to use the native backend with `org.bluez.obex` on the
session bus.

