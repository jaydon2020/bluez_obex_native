# bluez_obex_native

Native Dart bindings for BlueZ OBEX sessions, transfers, phonebook access, and
message access.

## Getting Started

The public API is object oriented and starts with `BlueZObexClient`.

```dart
final client = await BlueZObexClient.connect();
final session = await client.createSession(
  'AA:BB:CC:DD:EE:FF',
  target: 'pbap',
);

await session.phonebook.select('int', 'pb');
final entries = await session.phonebook.list(filters: {'MaxCount': 50});
final transfer = await session.phonebook.pullAll('/tmp/contacts.vcf');

await client.dispose();
```

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

* platform folders (`linux`, etc.): Contains the build files
  for building and bundling the native code library with the platform application.

## Building and bundling native code

The `pubspec.yaml` specifies FFI plugins as follows:

```yaml
  plugin:
    platforms:
      some_platform:
        ffiPlugin: true
```

This configuration invokes the native build for the various target platforms
and bundles the binaries in Flutter applications using these FFI plugins.

This can be combined with dartPluginClass, such as when FFI is used for the
implementation of one platform in a federated plugin:

```yaml
  plugin:
    implements: some_other_plugin
    platforms:
      some_platform:
        dartPluginClass: SomeClass
        ffiPlugin: true
```

A plugin can have both FFI and method channels:

```yaml
  plugin:
    platforms:
      some_platform:
        pluginClass: SomeName
        ffiPlugin: true
```

The native build systems that are invoked by FFI (and method channel) plugins are:

* For Linux: CMake.
  * See the documentation in linux/CMakeLists.txt.

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
flutter test test/codec_test.dart
flutter test test/simulated_obex_integration_test.dart
flutter analyze --fatal-infos
cmake -S native -B build/native-tests -DBUILD_TESTING=ON
cmake --build build/native-tests --target test_obex_types -j2
ctest --test-dir build/native-tests --output-on-failure
```

## Flutter help

For help getting started with Flutter, view our
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
