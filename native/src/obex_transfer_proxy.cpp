#include "obex_transfer_proxy.h"

#include "obex_client.h"
#include "obex_proxy_utils.h"

#include "../generated/transfer1_proxy.h"

namespace {

class GeneratedTransfer1Proxy final : public org::bluez::obex::Transfer1_proxy {
public:
  explicit GeneratedTransfer1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::Transfer1_proxy(proxy) {
    registerProxy();
  }
};

} // namespace

ObexTransferProxy::ObexTransferProxy(sdbus::IConnection &conn,
                                     std::string object_path)
    : conn_(conn), object_path_(std::move(object_path)),
      proxy_(sdbus::createProxy(conn_,
                                sdbus::ServiceName{ObexClient::kObexService},
                                sdbus::ObjectPath{object_path_})) {}

ObexTransferProxy::~ObexTransferProxy() = default;

void ObexTransferProxy::cancel() const {
  GeneratedTransfer1Proxy transfer{*proxy_};
  transfer.Cancel();
}

void ObexTransferProxy::suspend() const {
  GeneratedTransfer1Proxy transfer{*proxy_};
  transfer.Suspend();
}

void ObexTransferProxy::resume() const {
  GeneratedTransfer1Proxy transfer{*proxy_};
  transfer.Resume();
}

BlueZObexTransferProps ObexTransferProxy::properties() const {
  return obex::transfer_props_from_map(
      object_path_,
      obex::get_all_properties(conn_, ObexClient::kObexService, object_path_,
                               "org.bluez.obex.Transfer1"));
}

std::vector<uint8_t> ObexTransferProxy::encoded_properties() const {
  return glz::encode(properties());
}
