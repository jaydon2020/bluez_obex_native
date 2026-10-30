# Verification and release

Clone with `--recurse-submodules`. Native dependency source and license files
must be included in the pub archive; consumers do not need Git to build it.

## Host checks

Use a Linux host with the README build prerequisites. Private-bus tests also
require `dbus-daemon`, `python3-dbus` and `python3-gi`. CI fails if those are
missing. Local tests explicitly report a skip when the Python modules are absent.

```sh
dart pub get
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed lib example hook test
dart test
./scripts/clang_format.sh check
cmake -S native -B build -GNinja -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON
cmake --build build --parallel
ctest --test-dir build --output-on-failure
./scripts/clang_tidy.sh build
./scripts/asan.sh build-asan
./scripts/coverage.sh build-cov
dart run ffigen --config ffigen.yaml
git diff --exit-code -- lib/bluez_obex_native_bindings_generated.dart
```

Run the Flutter example suite from `example/flutter_phone_message` with
`flutter pub get` followed by `flutter test`.

## Package checks

From a clean release checkout, with dependencies already cached:

```sh
dart pub publish --dry-run
/usr/bin/python3 scripts/verify_package.py
```

The script uses pub's `--to-archive` option to create the exact upload payload
without uploading. It checks exclusions, source/license/doc inclusion, extracts
the archive without Git metadata, resolves a consumer offline, builds its Native
Assets, verifies C ABI exports, and runs a relocated application against a private
OBEX bus. A decoy library in its working directory must not be loaded. Release
tooling uses the current stable Dart SDK, including `dart build cli` and pub's
archive option; applications continue to declare Dart 3.10 as their minimum.

The archive excludes `build/`, `build-*/`, Python bytecode, editor settings,
`ARCHITECTURE.md`, and `task.md`. Review the dry-run file listing before release.
The two planning files remain local and do not belong in implementation commits.

CI runs Dart/private-bus and Flutter tests, native tests, analysis, formatting,
Dart binding generation, archive verification, sanitizers, and static native analysis.
Coverage runs on pull requests and release tags. Tag publication depends on the
same verification workflow and checks that the tag matches `pubspec.yaml`.

Automated pub.dev publication requires publisher-side repository/tag setup.
The workflow uses `dart-lang/setup-dart` for OIDC authentication. The first
publication of a new package requires an authorized manual publish; see
[Dart's publishing guide](https://dart.dev/tools/pub/automated-publishing).
Neither the test scripts nor package verification upload a package.

## AGL/Yocto and hardware limits

For source cross-builds, the recipe must expose target compilers, sysroot and
target pkg-config search paths to CMake. The hook does not execute the target
library. For recipe-supplied builds, `skip_native_build: true` delegates
artifact installation to the recipe; configure a trusted library override if
needed. Normal Dart asset loading requires the hook's bundled asset.

Host simulation/private-bus tests do not establish real phone or AGL support.
Before deploying, verify the actual target's BlueZ/obexd revision and bus policy,
phone access consent, supported filters, PBAP pulls/search, MAP operations,
transfer completion/error/cancellation, and recovery after phone disconnection,
obexd replacement and bus loss. Record unsupported phone features separately
from package failures. No real AGL/phone validation is claimed by this release.
