#include "obex_message_proxy.h"

#include "obex_client.h"
#include "obex_proxy_utils.h"

#include "../generated/message1_proxy.h"
#include "../generated/message_access1_proxy.h"

#include <tuple>

namespace {

class GeneratedMessageAccess1Proxy final
    : public org::bluez::obex::MessageAccess1_proxy {
public:
  explicit GeneratedMessageAccess1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::MessageAccess1_proxy(proxy) {
    registerProxy();
  }
};

class GeneratedMessage1Proxy final : public org::bluez::obex::Message1_proxy {
public:
  explicit GeneratedMessage1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::Message1_proxy(proxy) {
    registerProxy();
  }
};

BlueZObexMessageFolders
to_folders(const std::vector<std::map<std::string, sdbus::Variant>> &items) {
  BlueZObexMessageFolders result;
  result.folders.reserve(items.size());
  for (const auto &item : items) {
    result.folders.push_back(
        {.name = obex::get_property_value<std::string>(item, "Name")});
  }
  return result;
}

BlueZObexMessages to_messages(
    const std::vector<
        sdbus::Struct<sdbus::ObjectPath, std::map<std::string, sdbus::Variant>>>
        &items) {
  BlueZObexMessages result;
  result.messages.reserve(items.size());
  for (const auto &item : items) {
    result.messages.push_back(
        obex::message_props_from_map(std::get<0>(item), std::get<1>(item)));
  }
  return result;
}

} // namespace

ObexMessageAccessProxy::ObexMessageAccessProxy(sdbus::IConnection &conn,
                                               std::string object_path)
    : conn_(conn), object_path_(std::move(object_path)),
      proxy_(sdbus::createProxy(conn_,
                                sdbus::ServiceName{ObexClient::kObexService},
                                sdbus::ObjectPath{object_path_})) {}

ObexMessageAccessProxy::~ObexMessageAccessProxy() = default;

void ObexMessageAccessProxy::set_folder(const std::string &name) const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  message_access.SetFolder(name);
}

BlueZObexMessageFolders ObexMessageAccessProxy::list_folders(
    const std::map<std::string, sdbus::Variant> &filter) const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  return to_folders(message_access.ListFolders(filter));
}

std::vector<uint8_t> ObexMessageAccessProxy::encoded_list_folders(
    const std::map<std::string, sdbus::Variant> &filter) const {
  return glz::encode(list_folders(filter));
}

BlueZObexFilterFields ObexMessageAccessProxy::list_filter_fields() const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  return {.fields = message_access.ListFilterFields()};
}

std::vector<uint8_t>
ObexMessageAccessProxy::encoded_list_filter_fields() const {
  return glz::encode(list_filter_fields());
}

BlueZObexMessages ObexMessageAccessProxy::list_messages(
    const std::string &folder,
    const std::map<std::string, sdbus::Variant> &filter) const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  return to_messages(message_access.ListMessages(folder, filter));
}

std::vector<uint8_t> ObexMessageAccessProxy::encoded_list_messages(
    const std::string &folder,
    const std::map<std::string, sdbus::Variant> &filter) const {
  return glz::encode(list_messages(folder, filter));
}

void ObexMessageAccessProxy::update_inbox() const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  message_access.UpdateInbox();
}

BlueZObexTransferResult ObexMessageAccessProxy::push_message(
    const std::string &source_file, const std::string &folder,
    const std::map<std::string, sdbus::Variant> &args) const {
  GeneratedMessageAccess1Proxy message_access{*proxy_};
  const auto [path, props] =
      message_access.PushMessage(source_file, folder, args);
  return obex::transfer_result_from_dbus(path, props);
}

ObexMessageProxy::ObexMessageProxy(sdbus::IConnection &conn,
                                   std::string object_path)
    : conn_(conn), object_path_(std::move(object_path)),
      proxy_(sdbus::createProxy(conn_,
                                sdbus::ServiceName{ObexClient::kObexService},
                                sdbus::ObjectPath{object_path_})) {}

ObexMessageProxy::~ObexMessageProxy() = default;

BlueZObexTransferResult ObexMessageProxy::get(const std::string &target_file,
                                              bool attachment) const {
  GeneratedMessage1Proxy message{*proxy_};
  const auto [path, props] = message.Get(target_file, attachment);
  return obex::transfer_result_from_dbus(path, props);
}

std::vector<uint8_t>
ObexMessageProxy::encoded_get(const std::string &target_file,
                              bool attachment) const {
  return glz::encode(get(target_file, attachment));
}

void ObexMessageProxy::set_read(bool read) const {
  GeneratedMessage1Proxy message{*proxy_};
  message.Read(read);
}

void ObexMessageProxy::set_deleted(bool deleted) const {
  GeneratedMessage1Proxy message{*proxy_};
  message.Deleted(deleted);
}

BlueZObexMessageProps ObexMessageProxy::properties() const {
  return obex::message_props_from_map(
      object_path_,
      obex::get_all_properties(conn_, ObexClient::kObexService, object_path_,
                               "org.bluez.obex.Message1"));
}

std::vector<uint8_t> ObexMessageProxy::encoded_properties() const {
  return glz::encode(properties());
}
