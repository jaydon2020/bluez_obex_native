#include "obex_session_proxy.h"

#include "obex_client.h"
#include "obex_proxy_utils.h"

#include "../generated/client1_proxy.h"
#include "../generated/session1_proxy.h"

namespace {

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
                       sdbus::ObjectPath{ObexClient::kObexRootPath})) {}

ObexSessionManager::~ObexSessionManager() = default;

BlueZObexSessionProps ObexSessionManager::create_session(
    const std::string &destination,
    const std::map<std::string, sdbus::Variant> &args) const {
  GeneratedClient1Proxy client{*proxy_};
  const auto session_path = client.CreateSession(destination, args);

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
