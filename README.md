# bluez_obex_native

Native Dart bindings for BlueZ OBEX sessions, transfers, phonebook access, and
message access.

## Getting Started

The public API is object oriented and starts with `BlueZObexClient`.
Session creation defaults to `pbap`; use `target: 'map'` for messages.
An explicitly empty target is rejected.

```dart
final client = await BlueZObexClient.connect();
try {
  final session = await client.createSession(
    'AA:BB:CC:DD:EE:FF',
    target: 'pbap',
  );
  await session.phonebook.select('int', 'pb');
  final entries = await session.phonebook.list(filters: {'MaxCount': 50});
  print(entries.map((entry) => entry.name).join('\n'));
} finally {
  await client.dispose();
}
```

The Dart API exposes every method and property in the bundled current BlueZ
`Client1`, `Session1`, `Transfer1`, `PhonebookAccess1`, `MessageAccess1`, and
`Message1` interfaces. ObjectManager additions, removals, and property changes
are delivered through `client.events`. Bus disconnection or an OBEX service
restart emits an error and `streamDone`, then closes the stream. Discard the
old object proxies, dispose the client, and connect again to obtain fresh state.
Always await `client.dispose()` to release its worker isolate and bus connection.

`pullAll`, `pull`, `get`, and `pushMessage` return when a transfer starts.
Subscribe to transfer events before starting the operation and wait for
`Status == 'complete'` before reading files or disposing the client. Removal
alone does not prove success. The [download examples](example/README.md)
demonstrate this sequence.

## Linux prerequisites

Use Dart 3.10 or later (or a Flutter release containing that SDK), CMake,
pkg-config, a C++23 compiler, and libsystemd development files. On Ubuntu 24.04:

```sh
sudo apt-get install cmake ninja-build g++ pkg-config libsystemd-dev bluez-obexd
```

BlueZ must already pair/connect the phone and the phone must grant contact or
message access. OBEX uses the application's **session bus**; device discovery
uses the **system bus**. Run as the desktop/application user with a reachable
`org.bluez.obex` service. This package does not pair devices or change bus policy.

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
native library automatically. The hook requires a Linux host and Linux target.
For cross-architecture builds, provide a CMake toolchain file through the root
application's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    bluez_obex_native:
      cmake_toolchain_file: /path/to/agl-toolchain.cmake
```

The toolchain must select the target C/C++ compilers and define
`CMAKE_SYSROOT`; the hook refuses to label a host build as a foreign target.
Native Assets runs hooks in a semi-hermetic environment, so Yocto must use this
user-define rather than relying on `CC`, `CXX`, or `SDKTARGETSYSROOT` being
visible inside the hook. A recipe that builds and injects the library itself can
set `skip_native_build: true` in the same section. `SKIP_NATIVE_BUILD` remains
available for direct/legacy hook execution. `BLUEZ_OBEX_LIB` explicitly loads a
trusted prebuilt library during development. Normal loading uses the declared
Native Asset; it does not search the working directory or development caches.
The hook checks the built ELF architecture before bundling it.

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

## Acknowledgements

* [bluez_native](https://github.com/jwinarske/bluez_native) (Apache-2.0): the
  Native Assets build hook, library loader, glaze binary codec, FFI handle
  lifetime design, and development scripts are derived from this project.
* [appstream_dart](https://github.com/meta-flutter/appstream_dart)
  (Apache-2.0): the original pattern for the build hook and library loader.
* [sdbus-c++](https://github.com/Kistler-Group/sdbus-cpp) (LGPL-2.1): the
  D-Bus C++ binding used by the native library.

## Verification

```sh
dart test
dart analyze
cmake -S native -B build/native-tests -DBUILD_TESTING=ON
cmake --build build/native-tests -j2
ctest --test-dir build/native-tests --output-on-failure
```

Release verification, including the exact pub archive, an offline consumer build
and loading a relocated bundle, is documented in [docs/verification.md](docs/verification.md).

## Flutter help

For help getting started with Flutter, view our
[online documentation](https://docs.flutter.dev), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
