/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#pragma once

#include <sdbus-c++/sdbus-c++.h>

#include <cstdint>
#include <map>
#include <string>
#include <vector>

class ObexClient {
public:
  explicit ObexClient(sdbus::IConnection &conn);
  ~ObexClient();

  ObexClient(const ObexClient &) = delete;
  ObexClient &operator=(const ObexClient &) = delete;

  sdbus::IConnection &connection() { return conn_; }

  std::vector<uint8_t> get_managed_objects() const;

  static constexpr auto kObexService = "org.bluez.obex";
  // Path for the org.bluez.obex.Client1 interface
  // (CreateSession/RemoveSession).
  static constexpr auto kObexClientPath = "/org/bluez/obex";
  // Path for the org.freedesktop.DBus.ObjectManager interface
  // (GetManagedObjects).
  static constexpr auto kObexRootPath = "/";
  static constexpr auto kObjectManagerIface =
      "org.freedesktop.DBus.ObjectManager";

private:
  sdbus::IConnection &conn_;
};
