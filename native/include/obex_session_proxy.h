#pragma once

#include "bluez_obex_types.h"

#include <sdbus-c++/sdbus-c++.h>

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

class ObexSessionProxy {
public:
  ObexSessionProxy(sdbus::IConnection &conn, std::string object_path);
  ~ObexSessionProxy();

  ObexSessionProxy(const ObexSessionProxy &) = delete;
  ObexSessionProxy &operator=(const ObexSessionProxy &) = delete;

  std::string get_capabilities() const;
  BlueZObexSessionProps properties() const;
  std::vector<uint8_t> encoded_properties() const;

private:
  sdbus::IConnection &conn_;
  std::string object_path_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};

class ObexSessionManager {
public:
  explicit ObexSessionManager(sdbus::IConnection &conn);
  ~ObexSessionManager();

  ObexSessionManager(const ObexSessionManager &) = delete;
  ObexSessionManager &operator=(const ObexSessionManager &) = delete;

  BlueZObexSessionProps
  create_session(const std::string &destination,
                 const std::map<std::string, sdbus::Variant> &args = {}) const;
  std::vector<uint8_t> encoded_create_session(
      const std::string &destination,
      const std::map<std::string, sdbus::Variant> &args = {}) const;
  void remove_session(const std::string &session_path) const;

private:
  sdbus::IConnection &conn_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};
