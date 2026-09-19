/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "bluez_obex_native.h"

#include <cassert>
#include <cstdint>

namespace {

void expect_stale_handle_rejected(void *handle) {
  uint8_t *out = nullptr;
  constexpr auto path = "/org/bluez/obex/client/session0";
  constexpr auto value = "value";

  assert(bluez_obex_get_managed_objects(handle, &out) == -1);
  assert(bluez_obex_client_create_session(handle, value, value, &out) ==
         -1);
  assert(bluez_obex_client_remove_session(handle, path) == -1);
  assert(bluez_obex_session_get_properties(handle, path, &out) == -1);
  assert(bluez_obex_session_get_capabilities(handle, path, &out) == -1);
  assert(bluez_obex_transfer_get_properties(handle, path, &out) == -1);
  assert(bluez_obex_transfer_cancel(handle, path) == -1);
  assert(bluez_obex_transfer_suspend(handle, path) == -1);
  assert(bluez_obex_transfer_resume(handle, path) == -1);
  assert(bluez_obex_phonebook_get_properties(handle, path, &out) == -1);
  assert(bluez_obex_phonebook_select(handle, path, value, value) == -1);
  assert(bluez_obex_phonebook_pull_all(handle, path, value, nullptr, nullptr, 0,
                                       &out) == -1);
  assert(bluez_obex_phonebook_pull(handle, path, value, value, nullptr, nullptr,
                                   0, &out) == -1);
  assert(bluez_obex_phonebook_list(handle, path, nullptr, nullptr, 0, &out) == -1);
  assert(bluez_obex_phonebook_search(handle, path, value, value, nullptr,
                                     nullptr, 0, &out) == -1);
  assert(bluez_obex_phonebook_get_size(handle, path) == -1);
  assert(bluez_obex_phonebook_update_version(handle, path) == -1);
  assert(bluez_obex_phonebook_list_filter_fields(handle, path, &out) ==
         -1);
  assert(bluez_obex_message_access_set_folder(handle, path, value) == -1);
  assert(bluez_obex_message_access_get_properties(handle, path, &out) ==
         -1);
  assert(bluez_obex_message_access_list_folders(handle, path, nullptr, nullptr,
                                                0, &out) == -1);
  assert(bluez_obex_message_access_list_filter_fields(handle, path, &out) == -1);
  assert(bluez_obex_message_access_list_messages(handle, path, value, nullptr,
                                                 nullptr, 0, &out) == -1);
  assert(bluez_obex_message_access_update_inbox(handle, path) == -1);
  assert(bluez_obex_message_access_push_message(handle, path, value, value,
                                                nullptr, nullptr, 0, &out) == -1);
  assert(bluez_obex_message_get_properties(handle, path, &out) == -1);
  assert(bluez_obex_message_get(handle, path, value, 1, &out) == -1);
  assert(bluez_obex_message_set_read(handle, path, 1) == -1);
  assert(bluez_obex_message_set_deleted(handle, path, 1) == -1);
}

} // namespace

int main() {
  bluez_obex_init(nullptr);
  assert(bluez_obex_client_create(0) == nullptr);

  expect_stale_handle_rejected(nullptr);
  expect_stale_handle_rejected(
      reinterpret_cast<void *>(static_cast<uintptr_t>(0xdeadbeef)));

  // Destroy is deliberately idempotent for null, never-issued, and already
  // retired tokens. Reaching the end proves no pointer was dereferenced.
  bluez_obex_client_destroy(nullptr);
  auto *bogus = reinterpret_cast<void *>(static_cast<uintptr_t>(0xdeadbeef));
  bluez_obex_client_destroy(bogus);
  bluez_obex_client_destroy(bogus);
}
