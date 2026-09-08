#pragma once

#include <sdbus-c++/sdbus-c++.h>

#include <map>
#include <memory>
#include <mutex>
#include <set>
#include <string>
#include <vector>

#include "bluez_obex_types.h"
#include "dart_api_dl.h"

class ObexObjectManager {
public:
  using PropertiesMap = std::map<std::string, sdbus::Variant>;
  using InterfacesMap = std::map<std::string, PropertiesMap>;

  ObexObjectManager(sdbus::IConnection &conn, Dart_Port_DL events_port);
  ~ObexObjectManager();

  ObexObjectManager(const ObexObjectManager &) = delete;
  ObexObjectManager &operator=(const ObexObjectManager &) = delete;

  void get_managed_objects();
  void connection_failed(const std::string &message) noexcept;

  static BlueZObexSessionProps
  extract_session_props(const std::string &object_path,
                        const PropertiesMap &props);

  static BlueZObexTransferProps
  extract_transfer_props(const std::string &object_path,
                         const PropertiesMap &props);

  static BlueZObexPhonebookProps
  extract_phonebook_props(const std::string &object_path,
                          const PropertiesMap &props);

  static BlueZObexMessageProps
  extract_message_props(const std::string &object_path,
                        const PropertiesMap &props);

  static BlueZObexMessageAccessProps
  extract_message_access_props(const std::string &object_path,
                               const PropertiesMap &props);

private:
  static constexpr auto kObexService = "org.bluez.obex";
  static constexpr auto kObexRootPath = "/";
  static constexpr auto kObjectManagerIface =
      "org.freedesktop.DBus.ObjectManager";
  static constexpr auto kPropertiesIface = "org.freedesktop.DBus.Properties";
  static constexpr auto kSessionIface = "org.bluez.obex.Session1";
  static constexpr auto kTransferIface = "org.bluez.obex.Transfer1";
  static constexpr auto kPhonebookIface = "org.bluez.obex.PhonebookAccess1";
  static constexpr auto kMessageAccessIface = "org.bluez.obex.MessageAccess1";
  static constexpr auto kMessageIface = "org.bluez.obex.Message1";

  void on_interfaces_added(const sdbus::ObjectPath &object_path,
                           const InterfacesMap &interfaces);
  void on_interfaces_removed(const sdbus::ObjectPath &object_path,
                             const std::vector<std::string> &interfaces);
  void subscribe_properties(const std::string &object_path);
  void post_properties(const std::string &object_path,
                       const std::string &interface_name,
                       const PropertiesMap *properties = nullptr);
  void post_removed(const std::string &object_path,
                    const std::string &interface_name);
  void post_added(const std::string &object_path,
                  const std::string &interface_name);
  void post_error(const std::string &object_path, const std::string &name,
                  const std::string &message);

  template <typename T> void post_glaze(uint8_t discriminator, const T &value);
  void post_bytes(uint8_t discriminator, const std::vector<uint8_t> &payload);
  void post_sentinel(uint8_t discriminator);

  sdbus::IConnection &conn_;
  Dart_Port_DL events_port_;
  std::unique_ptr<sdbus::IProxy> root_proxy_;

  std::mutex mutex_;
  std::map<std::string, std::unique_ptr<sdbus::IProxy>> property_proxies_;
  std::map<std::string, std::set<std::string>> interfaces_by_path_;
};
