# bluez_obex_native

Native Dart bindings for BlueZ OBEX sessions, transfers, phonebook access, and
message access.

## Getting Started

The public API is object oriented and starts with `BlueZObexClient`.
Session creation defaults to `pbap`; use `target: 'map'` for messages.
An explicitly empty target is rejected.

```dart
final client = await BlueZObexClient.connect();
final session = await client.createSession(
  'AA:BB:CC:DD:EE:FF',
  target: 'pbap',
);

await session.phonebook.select('int', 'pb');
final entries = await session.phonebook.list(filters: {'MaxCount': 50});
final transfer = await session.phonebook.pullAll('/tmp/contacts.vcf');

final ada = await session.phonebook.pull('1.vcf', '/tmp/ada.vcf');
final activeTransfer = client.transfer(ada.transferPath);
await activeTransfer.suspend();
await activeTransfer.resume();

await client.dispose();
```

The Dart API exposes every method and property in the bundled current BlueZ
`Client1`, `Session1`, `Transfer1`, `PhonebookAccess1`, `MessageAccess1`, and
`Message1` interfaces. ObjectManager additions, removals, and property changes
are delivered through `client.events`.

For CI and local development without Bluetooth hardware, use the simulated
endpoint:

```dart
final client = await BlueZObexClient.simulated();
```

## Project structure

This template uses the following structure:

* `native`: Contains the native C/C++ source, generated sdbus-c++ proxies,
  D-Bus XML interfaces, and CMake configuration.

* `lib`: Contains the Dart code that defines the API of the plugin, and which
  calls into the native code using `dart:ffi`.

* `hook`: Contains the Dart native-assets build hook that compiles and bundles
  the shared library for consumers.

## Building and bundling native code

`hook/build.dart` drives CMake and declares `libbluez_obex_native.so` as a
bundled CodeAsset. Dart and Flutter consumers therefore build and package the
native library automatically. Set `SKIP_NATIVE_BUILD` to skip the hook or
`BLUEZ_OBEX_LIB` to load a specific prebuilt library during development.

## Binding to native code

To use the native code, bindings in Dart are needed.
To avoid writing these by hand, they are generated from the header file
(`native/include/bluez_obex_native.h`) by `package:ffigen`.
Regenerate the bindings by running `dart run ffigen --config ffigen.yaml`.

## Invoking native code

Use `BlueZObexClient` as the entry point. It initializes the Dart Native DL API,
opens a session bus connection, starts the native D-Bus event loop, and exposes
ObjectManager updates through `events`.

```dart
final client = await BlueZObexClient.connect();
final objects = await client.getManagedObjects();

final session = await client.createSession(
  'AA:BB:CC:DD:EE:FF',
  target: 'pbap',
);
final phonebook = session.phonebook;
await phonebook.select('int', 'pb');
final entries = await phonebook.list(filters: {'MaxCount': 50});

await client.dispose();
```

## Documentation

* [API reference](docs/api.md)
* [Verification guide](docs/verification.md)

## Verification

```sh
dart test
dart analyze
cmake -S native -B build/native-tests -DBUILD_TESTING=ON
cmake --build build/native-tests --target test_obex_types -j2
ctest --test-dir build/native-tests --output-on-failure
```

## Flutter help

For help getting started with Flutter, view our
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
