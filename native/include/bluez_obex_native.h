#pragma once

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

// ── Client lifecycle ────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT void bluez_obex_init(void *dart_api_dl_data);
FFI_PLUGIN_EXPORT void *bluez_obex_client_create(int64_t events_port);
FFI_PLUGIN_EXPORT void bluez_obex_client_destroy(void *handle);

// ── ObjectManager queries ──────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int bluez_obex_get_managed_objects(void *handle, uint8_t *out,
                                                     int32_t capacity);

// A very short-lived native function.
//
// For very short-lived functions, it is fine to call them on the main isolate.
// They will block the Dart execution while running the native function, so
// only do this for native functions which are guaranteed to be short-lived.
FFI_PLUGIN_EXPORT int sum(int a, int b);

// A longer lived native function, which occupies the thread calling it.
//
// Do not call these kind of native functions in the main isolate. They will
// block Dart execution. This will cause dropped frames in Flutter applications.
// Instead, call these native functions on a separate isolate.
FFI_PLUGIN_EXPORT int sum_long_running(int a, int b);

#ifdef __cplusplus
}
#endif
