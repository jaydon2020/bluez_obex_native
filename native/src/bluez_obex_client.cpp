// bluez_obex_client.cpp - C ABI entry points for BlueZ OBEX native client.

#include "bluez_obex_native.h"

#include <sdbus-c++/sdbus-c++.h>

#include <atomic>
#include <cstdio>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>

#include "bluez_device_registry.h"
#include "dart_api_dl.h"
#include "obex_client.h"
#include "obex_message_proxy.h"
#include "obex_object_manager.h"
#include "obex_phonebook_proxy.h"
#include "obex_proxy_utils.h"
#include "obex_session_proxy.h"
#include "obex_transfer_proxy.h"

struct BluezObexClientContext {
  std::unique_ptr<sdbus::IConnection> conn;
  std::unique_ptr<ObexClient> client;
  std::unique_ptr<ObexObjectManager> object_manager;
  Dart_Port_DL events_port{};
  std::thread event_loop;
  std::atomic_bool failed{false};

  void stop() noexcept {
    try {
      conn->leaveEventLoop();
    } catch (...) {
      // The bus may already be disconnected. The loop reports that failure.
    }
    if (event_loop.joinable()) event_loop.join();
  }

  ~BluezObexClientContext() {
    if (conn) stop();
  }
};

namespace {
std::atomic_bool dart_api_initialized{false};
std::mutex dart_api_mutex;

struct ClientRegistry {
  std::mutex mutex;
  std::unordered_map<uint64_t, std::shared_ptr<BluezObexClientContext>> clients;
  uint64_t next_id{1};
};

ClientRegistry &registry() {
  static ClientRegistry value;
  return value;
}

// Dart carries the non-reused registry token as an opaque pointer. Keeping
// this conversion here prevents stale handles from ever being dereferenced.
// NOLINTBEGIN(cppcoreguidelines-pro-type-reinterpret-cast)
uint64_t token_of(void *handle) {
  return static_cast<uint64_t>(reinterpret_cast<uintptr_t>(handle));
}

void *handle_of(uint64_t token) {
  return reinterpret_cast<void *>(static_cast<uintptr_t>(token));
}
// NOLINTEND(cppcoreguidelines-pro-type-reinterpret-cast)

std::shared_ptr<BluezObexClientContext> client_for(void *handle) {
  auto &clients = registry();
  const std::lock_guard lock(clients.mutex);
  const auto it = clients.clients.find(token_of(handle));
  return it == clients.clients.end() || it->second->failed.load()
             ? nullptr : it->second;
}

int copy_payload(const std::vector<uint8_t> &payload, uint8_t *out,
                 int32_t capacity) {
  if (capacity < 0 || payload.size() > INT32_MAX) {
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
  if (capacity < 0 || payload.size() > INT32_MAX) {
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

std::map<std::string, sdbus::Variant>
make_variant_map(const char **keys, const char **values, int32_t count) {
  if (count < 0) {
    throw std::invalid_argument("filter count must be non-negative");
  }
  if (count == 0) {
    return {};
  }
  if (keys == nullptr || values == nullptr) {
    throw std::invalid_argument("filter keys and values must be non-null");
  }

  std::map<std::string, std::string> strings;
  for (int32_t i = 0; i < count; ++i) {
    const auto key = cstr_or_empty(keys[i]);
    strings[key] = cstr_or_empty(values[i]);
  }
  return obex::variant_map_from_strings(strings);
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
  if (dart_api_dl_data == nullptr) {
    return;
  }
  const std::lock_guard lock(dart_api_mutex);
  if (!dart_api_initialized.load()) {
    dart_api_initialized.store(Dart_InitializeApiDL(dart_api_dl_data) == 0);
  }
}

FFI_PLUGIN_EXPORT void *bluez_obex_client_create(int64_t events_port) {
  if (!dart_api_initialized.load() || events_port == 0) {
    return nullptr;
  }
  try {
    auto ctx = std::make_unique<BluezObexClientContext>();
    ctx->events_port = events_port;
    ctx->conn = sdbus::createSessionBusConnection();
    ctx->client = std::make_unique<ObexClient>(*ctx->conn);
    ctx->object_manager =
        std::make_unique<ObexObjectManager>(*ctx->conn, ctx->events_port);
    ctx->object_manager->get_managed_objects();
    ctx->event_loop =
        std::thread([context = ctx.get()]() {
          try {
            context->conn->enterEventLoop();
          } catch (const std::exception &error) {
            context->failed.store(true);
            context->object_manager->connection_failed(error.what());
          } catch (...) {
            context->failed.store(true);
            context->object_manager->connection_failed("Unknown event loop failure");
          }
        });
    std::shared_ptr<BluezObexClientContext> client = std::move(ctx);
    uint64_t id{};
    {
      auto &clients = registry();
      const std::lock_guard lock(clients.mutex);
      id = clients.next_id++;
      clients.clients.emplace(id, std::move(client));
    }
    return handle_of(id);
  } catch (const sdbus::Error &e) {
    fprintf(stderr, "bluez_obex_client_create: %s\n", e.what());
    return nullptr;
  } catch (const std::exception &e) {
    fprintf(stderr, "bluez_obex_client_create: %s\n", e.what());
    return nullptr;
  }
}

FFI_PLUGIN_EXPORT void bluez_obex_client_destroy(void *handle) {
  std::shared_ptr<BluezObexClientContext> ctx;
  {
    auto &clients = registry();
    const std::lock_guard lock(clients.mutex);
    const auto it = clients.clients.find(token_of(handle));
    if (it == clients.clients.end()) {
      return;
    }
    ctx = std::move(it->second);
    clients.clients.erase(it);
  }
  ctx->stop();
}

FFI_PLUGIN_EXPORT int bluez_obex_client_create_session(void *handle,
                                                       const char *destination,
                                                       const char *target,
                                                       uint8_t *out,
                                                       int32_t capacity) {
  if (handle == nullptr || destination == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_client_create_session",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_client_remove_session", [=]() {
    ObexSessionManager{*ctx->conn}.remove_session(session_path);
  });
}

FFI_PLUGIN_EXPORT int
bluez_obex_session_get_properties(void *handle, const char *session_path,
                                  uint8_t *out, int32_t capacity) {
  if (handle == nullptr || session_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_session_get_properties",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  try {
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

FFI_PLUGIN_EXPORT int
bluez_obex_transfer_get_properties(void *handle, const char *transfer_path,
                                   uint8_t *out, int32_t capacity) {
  if (handle == nullptr || transfer_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_transfer_get_properties",
      [=]() {
        return ObexTransferProxy{*ctx->conn, transfer_path}
            .encoded_properties();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_transfer_cancel(void *handle,
                                                 const char *transfer_path) {
  if (handle == nullptr || transfer_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_transfer_cancel", [=]() {
    ObexTransferProxy{*ctx->conn, transfer_path}.cancel();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_transfer_suspend(void *handle,
                                                  const char *transfer_path) {
  if (handle == nullptr || transfer_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_transfer_suspend", [=]() {
    ObexTransferProxy{*ctx->conn, transfer_path}.suspend();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_transfer_resume(void *handle,
                                                 const char *transfer_path) {
  if (handle == nullptr || transfer_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_transfer_resume", [=]() {
    ObexTransferProxy{*ctx->conn, transfer_path}.resume();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_get_managed_objects(void *handle, uint8_t *out,
                                                     int32_t capacity) {
  if (handle == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  try {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_get_properties",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_phonebook_select", [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_pull_all",
      [=]() {
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}.encoded_pull_all(
            target_file,
            make_variant_map(filter_keys, filter_values, filter_count));
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int
bluez_obex_phonebook_pull(void *handle, const char *phonebook_path,
                          const char *vcard, const char *target_file,
                          const char **filter_keys, const char **filter_values,
                          int32_t filter_count, uint8_t *out,
                          int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr || vcard == nullptr ||
      target_file == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_pull",
      [=]() {
        return ObexPhonebookProxy{*ctx->conn, phonebook_path}.encoded_pull(
            vcard, target_file,
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_list",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_search",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  try {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_phonebook_update_version", [=]() {
    ObexPhonebookProxy{*ctx->conn, phonebook_path}.update_version();
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_phonebook_list_filter_fields(
    void *handle, const char *phonebook_path, uint8_t *out, int32_t capacity) {
  if (handle == nullptr || phonebook_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_phonebook_list_filter_fields",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_message_access_set_folder", [=]() {
    ObexMessageAccessProxy{*ctx->conn, message_access_path}.set_folder(folder);
  });
}

FFI_PLUGIN_EXPORT int
bluez_obex_message_access_get_properties(void *handle,
                                         const char *message_access_path,
                                         uint8_t *out, int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_get_properties",
      [=]() {
        return ObexMessageAccessProxy{*ctx->conn, message_access_path}
            .encoded_properties();
      },
      out, capacity);
}

FFI_PLUGIN_EXPORT int bluez_obex_message_access_list_folders(
    void *handle, const char *message_access_path, const char **filter_keys,
    const char **filter_values, int32_t filter_count, uint8_t *out,
    int32_t capacity) {
  if (handle == nullptr || message_access_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_folders",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_filter_fields",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_list_messages",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_message_access_update_inbox", [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_access_push_message",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_get_properties",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_bytes(
      "bluez_obex_message_get",
      [=]() {
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
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_message_set_read", [=]() {
    ObexMessageProxy{*ctx->conn, message_path}.set_read(read != 0);
  });
}

FFI_PLUGIN_EXPORT int bluez_obex_message_set_deleted(void *handle,
                                                     const char *message_path,
                                                     int deleted) {
  if (handle == nullptr || message_path == nullptr) {
    return -1;
  }
  const auto ctx = client_for(handle);
  if (!ctx) {
    return -1;
  }
  return call_status("bluez_obex_message_set_deleted", [=]() {
    ObexMessageProxy{*ctx->conn, message_path}.set_deleted(deleted != 0);
  });
}

} // extern "C"
