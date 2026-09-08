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

// Byte-returning functions allocate *out and return its length (or a negative
// status on failure). Call bluez_obex_free on successful results, including
// empty results. Each operation executes exactly once; there is no sizing call.
FFI_PLUGIN_EXPORT void bluez_obex_free(void *buffer);

// ── Client lifecycle ────────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int bluez_obex_get_devices(uint8_t **out);

FFI_PLUGIN_EXPORT void bluez_obex_init(void *dart_api_dl_data);
FFI_PLUGIN_EXPORT void *bluez_obex_client_create(int64_t events_port);
FFI_PLUGIN_EXPORT void bluez_obex_client_destroy(void *handle);

// ── Session management ─────────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int bluez_obex_client_create_session(void *handle,
                                                       const char *destination,
                                                       const char *target,
                                                       uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_client_remove_session(void *handle, const char *session_path);
FFI_PLUGIN_EXPORT int
bluez_obex_session_get_properties(void *handle, const char *session_path,
                                  uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_session_get_capabilities(void *handle, const char *session_path,
                                    uint8_t **out);

// ── Transfer management ──────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int
bluez_obex_transfer_get_properties(void *handle, const char *transfer_path,
                                   uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_transfer_cancel(void *handle,
                                                 const char *transfer_path);
FFI_PLUGIN_EXPORT int bluez_obex_transfer_suspend(void *handle,
                                                  const char *transfer_path);
FFI_PLUGIN_EXPORT int bluez_obex_transfer_resume(void *handle,
                                                 const char *transfer_path);

// ── ObjectManager queries ──────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int bluez_obex_get_managed_objects(void *handle, uint8_t **out);

// ── Phonebook Access Profile ───────────────────────────────────────────────

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_get_properties(void *handle, const char *phonebook_path,
                                    uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_phonebook_select(void *handle,
                                                  const char *phonebook_path,
                                                  const char *location,
                                                  const char *phonebook);
FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_pull_all(void *handle, const char *phonebook_path,
                              const char *target_file, const char **filter_keys,
                              const char **filter_values, int32_t filter_count,
                              uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_pull(void *handle, const char *phonebook_path,
                          const char *vcard, const char *target_file,
                          const char **filter_keys, const char **filter_values,
                          int32_t filter_count, uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_list(void *handle, const char *phonebook_path,
                          const char **filter_keys, const char **filter_values,
                          int32_t filter_count, uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_phonebook_search(
    void *handle, const char *phonebook_path, const char *field,
    const char *value, const char **filter_keys, const char **filter_values,
    int32_t filter_count, uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_phonebook_get_size(void *handle,
                                                    const char *phonebook_path);
FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_update_version(void *handle, const char *phonebook_path);
FFI_PLUGIN_EXPORT int bluez_obex_phonebook_list_filter_fields(
    void *handle, const char *phonebook_path, uint8_t **out);

// ── Message Access Profile ─────────────────────────────────────────────────

FFI_PLUGIN_EXPORT int
bluez_obex_message_access_get_properties(void *handle,
                                         const char *message_access_path,
                                         uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_message_access_set_folder(
    void *handle, const char *message_access_path, const char *folder);
FFI_PLUGIN_EXPORT int bluez_obex_message_access_list_folders(
    void *handle, const char *message_access_path, const char **filter_keys,
    const char **filter_values, int32_t filter_count, uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_message_access_list_filter_fields(void *handle,
                                             const char *message_access_path,
                                             uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_message_access_list_messages(
    void *handle, const char *message_access_path, const char *folder,
    const char **filter_keys, const char **filter_values, int32_t filter_count,
    uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_message_access_update_inbox(void *handle,
                                       const char *message_access_path);
FFI_PLUGIN_EXPORT int bluez_obex_message_access_push_message(
    void *handle, const char *message_access_path, const char *source_file,
    const char *folder, const char **arg_keys, const char **arg_values,
    int32_t arg_count, uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_message_get_properties(void *handle, const char *message_path,
                                  uint8_t **out);
FFI_PLUGIN_EXPORT int bluez_obex_message_get(void *handle,
                                             const char *message_path,
                                             const char *target_file,
                                             int attachment, uint8_t **out);
FFI_PLUGIN_EXPORT int
bluez_obex_message_set_read(void *handle, const char *message_path, int read);
FFI_PLUGIN_EXPORT int bluez_obex_message_set_deleted(void *handle,
                                                     const char *message_path,
                                                     int deleted);

#ifdef __cplusplus
}
#endif
