## Unreleased

* Byte-returning C functions now take `uint8_t **out`, allocate their result once,
  and require `bluez_obex_free`. Regenerate raw FFI consumers for this C ABI change.
  High-level Dart method signatures are unchanged.

## 0.0.1

* TODO: Describe initial release.
