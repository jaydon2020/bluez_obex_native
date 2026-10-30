## 0.1.1

* Build native assets with the compiler environment supplied by the host build,
  matching `bluez_native`; a CMake toolchain user define is no longer required.

## 0.1.0

* Initial Linux release with BlueZ OBEX sessions and transfers, PBAP contact
  operations, MAP messaging, and system-bus device discovery.
* Run blocking native operations in a worker isolate and preserve D-Bus error
  names/messages. Close safely after service replacement or bus failure.
* Bundle the native library through Dart Native Assets, validate its ELF
  architecture, and resolve the bundled asset without working-directory lookup.
* Resolve the native library beside a loaded Flutter `libapp.so` for AGL
  homescreen deployments without `LD_LIBRARY_PATH`.
* Reject embedded NUL input and preserve fast transfer events across path reuse.
* Include simulated operation, CLI/Flutter examples, private-bus regression tests,
  and archive/offline-build verification.
* Raw byte-returning C functions allocate `uint8_t **out` results. Release every
  result with `bluez_obex_free`; older development bindings must be regenerated.
