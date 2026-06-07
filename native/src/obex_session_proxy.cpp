#include "obex_session_proxy.h"

#include "obex_client.h"
#include "obex_proxy_utils.h"

#include "../generated/client1_proxy.h"
#include "../generated/session1_proxy.h"

#include <map>
#include <optional>
#include <string>

namespace {

constexpr auto kDbusObjectManagerIface = "org.freedesktop.DBus.ObjectManager";
constexpr auto kObexSessionIface = "org.bluez.obex.Session1";
constexpr auto kPbapTargetUuid = "0000112f-0000-1000-8000-00805f9b34fb";
constexpr auto kMapTargetUuid = "00001132-0000-1000-8000-00805f9b34fb";

using PropertiesMap = std::map<std::string, sdbus::Variant>;
using InterfacesMap = std::map<std::string, PropertiesMap>;
using ManagedObjectsMap = std::map<sdbus::ObjectPath, InterfacesMap>;

class GeneratedClient1Proxy final : public org::bluez::obex::Client1_proxy {
public:
  explicit GeneratedClient1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::Client1_proxy(proxy) {
    registerProxy();
  }
};

class GeneratedSession1Proxy final : public org::bluez::obex::Session1_proxy {
public:
  explicit GeneratedSession1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::Session1_proxy(proxy) {
    registerProxy();
  }
};

std::string
normalized_target(const std::map<std::string, sdbus::Variant> &args) {
  const auto it = args.find("Target");
  if (it == args.end()) {
    return {};
  }

  const auto target = it->second.get<std::string>();
  if (target == "pbap") {
    return kPbapTargetUuid;
  }
  if (target == "map") {
    return kMapTargetUuid;
  }
  return target;
}

std::optional<BlueZObexSessionProps>
find_existing_session(sdbus::IConnection &conn, const std::string &destination,
                      const std::map<std::string, sdbus::Variant> &args) {
  const auto target = normalized_target(args);
  // GetManagedObjects is on the ObjectManager at the root path "/"
  auto proxy =
      sdbus::createProxy(conn, sdbus::ServiceName{ObexClient::kObexService},
                         sdbus::ObjectPath{ObexClient::kObexRootPath});
  ManagedObjectsMap objects;
  proxy->callMethod("GetManagedObjects")
      .onInterface(kDbusObjectManagerIface)
      .storeResultsTo(objects);

  for (const auto &[path, interfaces] : objects) {
    const auto session = interfaces.find(kObexSessionIface);
    if (session == interfaces.end()) {
      continue;
    }

    auto props = obex::session_props_from_map(path, session->second);
    if (props.destination != destination) {
      continue;
    }
    if (!target.empty() && props.target != target) {
      continue;
    }
    return props;
  }
  return std::nullopt;
}

} // namespace

ObexSessionProxy::ObexSessionProxy(sdbus::IConnection &conn,
                                   std::string object_path)
    : conn_(conn), object_path_(std::move(object_path)),
      proxy_(sdbus::createProxy(conn_,
                                sdbus::ServiceName{ObexClient::kObexService},
                                sdbus::ObjectPath{object_path_})) {}

ObexSessionProxy::~ObexSessionProxy() = default;

std::string ObexSessionProxy::get_capabilities() const {
  GeneratedSession1Proxy session{*proxy_};
  return session.GetCapabilities();
}

BlueZObexSessionProps ObexSessionProxy::properties() const {
  return obex::session_props_from_map(
      object_path_,
      obex::get_all_properties(conn_, ObexClient::kObexService, object_path_,
                               "org.bluez.obex.Session1"));
}

std::vector<uint8_t> ObexSessionProxy::encoded_properties() const {
  return glz::encode(properties());
}

ObexSessionManager::ObexSessionManager(sdbus::IConnection &conn)
    : conn_(conn), proxy_(sdbus::createProxy(
                       conn_, sdbus::ServiceName{ObexClient::kObexService},
                       // Client1 interface lives at /org/bluez/obex
                       sdbus::ObjectPath{ObexClient::kObexClientPath})) {}

ObexSessionManager::~ObexSessionManager() = default;

BlueZObexSessionProps ObexSessionManager::create_session(
    const std::string &destination,
    const std::map<std::string, sdbus::Variant> &args) const {
  if (auto existing = find_existing_session(conn_, destination, args)) {
    return *existing;
  }

  GeneratedClient1Proxy client{*proxy_};
  sdbus::ObjectPath session_path;
  try {
    session_path = client.CreateSession(destination, args);
  } catch (const sdbus::Error &) {
    if (auto existing = find_existing_session(conn_, destination, args)) {
      return *existing;
    }
    throw;
  }

  BlueZObexSessionProps session;
  session.objectPath = session_path;
  session.destination = destination;
  try {
    session = ObexSessionProxy{conn_, session_path}.properties();
  } catch (const sdbus::Error &) {
  }
  return session;
}

std::vector<uint8_t> ObexSessionManager::encoded_create_session(
    const std::string &destination,
    const std::map<std::string, sdbus::Variant> &args) const {
  return glz::encode(create_session(destination, args));
}

void ObexSessionManager::remove_session(const std::string &session_path) const {
  GeneratedClient1Proxy client{*proxy_};
  client.RemoveSession(sdbus::ObjectPath{session_path});
}
