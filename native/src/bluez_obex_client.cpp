// bluez_obex_client.cpp - C ABI entry points for BlueZ OBEX native client.

#include "bluez_obex_native.h"

#include <sdbus-c++/sdbus-c++.h>

#include <charconv>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <string>
#include <thread>

#include "bluez_device_registry.h"
#include "dart_api_dl.h"
#include "obex_client.h"
#include "obex_message_proxy.h"
#include "obex_object_manager.h"
#include "obex_phonebook_proxy.h"
#include "obex_session_proxy.h"

struct BluezObexClientContext {
  std::unique_ptr<sdbus::IConnection> conn;
  std::unique_ptr<ObexClient> client;
  std::unique_ptr<ObexObjectManager> object_manager;
  Dart_Port_DL events_port{};
  std::thread event_loop;
};

namespace {
int copy_payload(const std::vector<uint8_t> &payload, uint8_t *out,
                 int32_t capacity) {
  if (capacity < 0) {
    return -1;
  }
  if (out == nullptr || capacity == 0) {
    return static_cast<int>(payload.size());
  }
  if (capacity < static_cast<int32_t>(payload.size())) {
    return -2;
  }
  std::memcpy(out, payload.data(), payload.size());
  return static_cast<int>(payload.size());
}

int copy_string_payload(const std::string &payload, uint8_t *out,
                        int32_t capacity) {
  if (capacity < 0) {
    return -1;
  }
  if (out == nullptr || capacity == 0) {
    return static_cast<int>(payload.size());
  }
  if (capacity < static_cast<int32_t>(payload.size())) {
    return -2;
  }
  std::memcpy(out, payload.data(), payload.size());
  return static_cast<int>(payload.size());
}

std::string cstr_or_empty(const char *value) {
  return value == nullptr ? std::string{} : std::string{value};
}

bool parse_uint16(const std::string &value, uint16_t &out) {
  uint32_t parsed{};
  const auto *begin = value.data();
  const auto *end = value.data() + value.size();
  const auto [ptr, ec] = std::from_chars(begin, end, parsed);
  if (ec != std::errc{} || ptr != end || parsed > UINT16_MAX) {
    return false;
  }
  out = static_cast<uint16_t>(parsed);
  return true;
}

std::vector<std::string> split_csv(const std::string &value) {
  std::vector<std::string> result;
  size_t start = 0;
  while (start <= value.size()) {
    const auto comma = value.find(',', start);
    const auto end = comma == std::string::npos ? value.size() : comma;
    if (end > start) {
      result.push_back(value.substr(start, end - start));
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return result;
}

bool is_uint16_filter_key(const std::string &key) {
  return key == "MaxCount" || key == "Offset" || key == "ListStartOffset" ||
         key == "StartOffset";
}

bool is_fields_filter_key(const std::string &key) {
  return key == "Fields" || key == "Filter";
}

std::map<std::string, sdbus::Variant>
make_variant_map(const char **keys, const char **values, int32_t count) {
  std::map<std::string, sdbus::Variant> result;
  if (count <= 0) {
    return result;
  }
  if (keys == nullptr || values == nullptr) {
    throw std::invalid_argument("filter keys and values must be non-null");
  }

  for (int32_t i = 0; i < count; ++i) {
    const auto key = cstr_or_empty(keys[i]);
    const auto value = cstr_or_empty(values[i]);
    if (key.empty()) {
      continue;
    }

    uint16_t parsed{};
    if (is_uint16_filter_key(key) && parse_uint16(value, parsed)) {
      result[key] = sdbus::Variant{parsed};
    } else if (is_fields_filter_key(key)) {
      result[key] = sdbus::Variant{split_csv(value)};
    } else if (value == "true" || value == "false") {
      result[key] = sdbus::Variant{value == "true"};
    } else {
      result[key] = sdbus::Variant{value};
    }
  }
  return result;
}

template <typename Fn>
int call_bytes(const char *label, Fn &&fn, uint8_t *out, int32_t capacity) {
  try {
    return copy_payload(fn(), out, capacity);
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "%s: %s\n", label, e.what());
    return -3;
  } catch (const std::exception &e) {
    fprintf(stderr, "%s: %s\n", label, e.what());
    return -3;
  }
}

template <typename Fn> int call_status(const char *label, Fn &&fn) {
  try {
    fn();
    return 0;
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "%s: %s\n", label, e.what());
    return -3;
  } catch (const std::exception &e) {
    fprintf(stderr, "%s: %s\n", label, e.what());
    return -3;
  }
}
} // namespace

extern "C" {

FFI_PLUGIN_EXPORT void bluez_obex_init(void *dart_api_dl_data) {
  Dart_InitializeApiDL(dart_api_dl_data);
}

FFI_PLUGIN_EXPORT void *bluez_obex_client_create(int64_t events_port) {
  try {
    auto ctx = std::make_unique<BluezObexClientContext>();
    ctx->events_port = events_port;
    ctx->conn = sdbus::createSessionBusConnection();
    ctx->client = std::make_unique<ObexClient>(*ctx->conn);
    ctx->object_manager =
        std::make_unique<ObexObjectManager>(*ctx->conn, ctx->events_port);
    ctx->object_manager->get_managed_objects();
    ctx->event_loop =
        std::thread([conn = ctx->conn.get()]() { conn->enterEventLoop(); });
    return ctx.release();
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "bluez_obex_client_create: %s\n", e.what());
    return nullptr;
  } catch (const std::exception &e) {
    fprintf(stderr, "bluez_obex_client_create: %s\n", e.what());
    return nullptr;
  }
}

FFI_PLUGIN_EXPORT void bluez_obex_client_destroy(void *handle) {
  auto *ctx = static_cast<BluezObexClientContext *>(handle);
  if (ctx == nullptr) {
    return;
  }
  ctx->conn->leaveEventLoop();
  if (ctx->event_loop.joinable()) {
    ctx->event_loop.join();
  }
  delete ctx; // NOLINT(cppcoreguidelines-owning-memory)
}

FFI_PLUGIN_EXPORT int bluez_obex_client_create_session(void *handle,
                                                       const char *destination,
                                                       const char *target,
                                                       uint8_t *out,
                                                       int32_t capacity) {
  if (handle == nullptr || destination == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_client_create_session",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        std::map<std::string, sdbus::Variant> args;
        const auto target_value = cstr_or_empty(target);
        if (!target_value.empty()) {
          args["Target"] = sdbus::Variant{target_value};
        }
        return ObexSessionManager{*ctx->conn}.encoded_create_session(
            destination, args);
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_client_remove_session(void *handle, const char *session_path) {
  if (handle == nullptr || session_path == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_client_remove_session", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexSessionManager{*ctx->conn}.remove_session(session_path);
  });
}

FFI_PLUGIN_EXPORT int
bluez_obex_session_get_properties(void *handle, const char *session_path,
                                  uint8_t *out, int32_t capacity) {
  if (handle == nullptr || session_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_session_get_properties",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexSessionProxy{*ctx->conn, session_path}.encoded_properties();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_session_get_capabilities(void *handle, const char *session_path,
                                    uint8_t *out, int32_t capacity) {
  if (handle == nullptr || session_path == nullptr) {
    return -1;
  }
  try {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    return copy_string_payload(
        ObexSessionProxy{*ctx->conn, session_path}.get_capabilities(), out,
        capacity);
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "bluez_obex_session_get_capabilities: %s\n", e.what());
    return -3;
  } catch (const std::exception &e) {
    fprintf(stderr, "bluez_obex_session_get_capabilities: %s\n", e.what());
    return -3;
  }
}

FFI_PLUGIN_EXPORT int bluez_obex_get_managed_objects(void *handle, uint8_t *out,
                                                     int32_t capacity) {
  if (handle == nullptr) {
    return -1;
  }
  try {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    return copy_payload(ctx->client->get_managed_objects(), out, capacity);
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "bluez_obex_get_managed_objects: %s\n", e.what());
    return -3;
  } catch (const std::exception &e) {
    fprintf(stderr, "bluez_obex_get_managed_objects: %s\n", e.what());
    return -3;
  }
}
FFI_PLUGIN_EXPORT int bluez_obex_get_devices(uint8_t *out, int32_t capacity) {
  return call_bytes(
      "bluez_obex_get_devices",
      []() { return glz::encode(BluezDeviceRegistry::get_devices()); }, out,
      capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_get_properties(void *handle, const char *phonebook_path,
                                    uint8_t *out, int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_get_properties",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}
            .encoded_properties();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_phonebook_select(void *handle,
                                                  const char *phonebook_path,
                                                  const char *location,
                                                  const char *phonebook) {
  if (handle == nullptr || phonebook_path == nullptr || location == nullptr ||
      phonebook == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_phonebook_select", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexPhonebookProxy{*ctx->conn, phonebook_path}.select(location, phonebook);
  });
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_pull_all(void *handle, const char *phonebook_path,
                              const char *target_file, const char **filter_keys,
                              const char **filter_values, int32_t filter_count,
                              uint8_t *out, int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr ||
      target_file == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_pull_all",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}.encoded_pull_all(
            target_file,
            make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_list(void *handle, const char *phonebook_path,
                          const char **filter_keys, const char **filter_values,
                          int32_t filter_count, uint8_t *out,
                          int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_list",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}.encoded_list(
            make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_phonebook_search(
    void *handle, const char *phonebook_path, const char *field,
    const char *value, const char **filter_keys, const char **filter_values,
    int32_t filter_count, uint8_t *out, int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr || field == nullptr ||
      value == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_search",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}.encoded_search(
            field, value,
            make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_get_size(void *handle, const char *phonebook_path) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  try {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    return ObexPhonebookProxy{*ctx->conn, phonebook_path}.get_size();
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "bluez_obex_phonebook_get_size: %s\n", e.what());
    return -3;
  } catch (const std::exception &e) {
    fprintf(stderr, "bluez_obex_phonebook_get_size: %s\n", e.what());
    return -3;
  }
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_update_version(void *handle, const char *phonebook_path) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_phonebook_update_version", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexPhonebookProxy{*ctx->conn, phonebook_path}.update_version();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_phonebook_list_filter_fields(
    void *handle, const char *phonebook_path, uint8_t *out, int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_list_filter_fields",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}
            .encoded_list_filter_fields();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_message_access_set_folder(
    void *handle, const char *message_access_path, const char *folder) {
  if (handle == nullptr || message_access_path == nullptr ||
      folder == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_message_access_set_folder", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexMessageAccessProxy{*ctx->conn, message_access_path}.set_folder(folder);
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_message_access_list_folders(
    void *handle, const char *message_access_path, const char **filter_keys,
    const char **filter_values, int32_t filter_count, uint8_t *out,
    int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_folders",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexMessageAccessProxy{*ctx->conn, message_access_path}
            .encoded_list_folders(
                make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_message_access_list_filter_fields(void *handle,
                                             const char *message_access_path,
                                             uint8_t *out, int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_filter_fields",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexMessageAccessProxy{*ctx->conn, message_access_path}
            .encoded_list_filter_fields();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_message_access_list_messages(
    void *handle, const char *message_access_path, const char *folder,
    const char **filter_keys, const char **filter_values, int32_t filter_count,
    uint8_t *out, int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr ||
      folder == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_messages",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexMessageAccessProxy{*ctx->conn, message_access_path}
            .encoded_list_messages(
                folder,
                make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_message_access_update_inbox(void *handle,
                                       const char *message_access_path) {
  if (handle == nullptr || message_access_path == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_message_access_update_inbox", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexMessageAccessProxy{*ctx->conn, message_access_path}.update_inbox();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_message_access_push_message(
    void *handle, const char *message_access_path, const char *source_file,
    const char *folder, const char **arg_keys, const char **arg_values,
    int32_t arg_count, uint8_t *out, int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr ||
      source_file == nullptr || folder == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_push_message",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return glz::encode(
            ObexMessageAccessProxy{*ctx->conn, message_access_path}
                .push_message(
                    source_file, folder,
                    make_variant_map(arg_keys, arg_values, arg_count)));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_message_get_properties(void *handle, const char *message_path,
                                  uint8_t *out, int32_t capacity) {
  if (handle == nullptr || message_path == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_get_properties",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexMessageProxy{*ctx->conn, message_path}.encoded_properties();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_message_get(void *handle,
                                             const char *message_path,
                                             const char *target_file,
                                             int attachment, uint8_t *out,
                                             int32_t capacity) {
  if (handle == nullptr || message_path == nullptr || target_file == nullptr) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_get",
      [=]() {
        auto *ctx = static_cast<BluezObexClientContext *>(handle);
        return ObexMessageProxy{*ctx->conn, message_path}.encoded_get(
            target_file, attachment != 0);
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_message_set_read(void *handle, const char *message_path, int read) {
  if (handle == nullptr || message_path == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_message_set_read", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexMessageProxy{*ctx->conn, message_path}.set_read(read != 0);
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_message_set_deleted(void *handle,
                                                     const char *message_path,
                                                     int deleted) {
  if (handle == nullptr || message_path == nullptr) {
    return -1;
  }
  return call_status("bluez_obex_message_set_deleted", [=]() {
    auto *ctx = static_cast<BluezObexClientContext *>(handle);
    ObexMessageProxy{*ctx->conn, message_path}.set_deleted(deleted != 0);
  });
}

} // extern "C"
