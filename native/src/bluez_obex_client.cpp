// bluez_obex_client.cpp - C ABI entry points for BlueZ OBEX native client.

#include "bluez_obex_native.h"

#include <sdbus-c++/sdbus-c++.h>

#include <cstdio>
#include <cstring>
#include <memory>
#include <thread>

#include "dart_api_dl.h"
#include "obex_client.h"
#include "obex_object_manager.h"

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

} // extern "C"
