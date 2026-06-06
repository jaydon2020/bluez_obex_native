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
  static constexpr auto kObexRootPath = "/org/bluez/obex";
  static constexpr auto kObjectManagerIface =
      "org.freedesktop.DBus.ObjectManager";

private:
  sdbus::IConnection &conn_;
};
