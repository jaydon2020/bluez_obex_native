#include "obex_phonebook_proxy.h"

#include "obex_client.h"
#include "obex_proxy_utils.h"

#include "../generated/phonebook_access1_proxy.h"

#include <tuple>

namespace {

class GeneratedPhonebookAccess1Proxy final
    : public org::bluez::obex::PhonebookAccess1_proxy {
public:
  explicit GeneratedPhonebookAccess1Proxy(sdbus::IProxy &proxy)
      : org::bluez::obex::PhonebookAccess1_proxy(proxy) {
    registerProxy();
  }
};

BlueZObexPhonebookEntries
to_entries(const std::vector<sdbus::Struct<std::string, std::string>> &items) {
  BlueZObexPhonebookEntries result;
  result.entries.reserve(items.size());
  for (const auto &item : items) {
    result.entries.push_back(
        {.vcard = std::get<0>(item), .name = std::get<1>(item)});
  }
  return result;
}

} // namespace

ObexPhonebookProxy::ObexPhonebookProxy(sdbus::IConnection &conn,
                                       std::string object_path)
    : conn_(conn), object_path_(std::move(object_path)),
      proxy_(sdbus::createProxy(conn_,
                                sdbus::ServiceName{ObexClient::kObexService},
                                sdbus::ObjectPath{object_path_})) {}

ObexPhonebookProxy::~ObexPhonebookProxy() = default;

void ObexPhonebookProxy::select(const std::string &location,
                                const std::string &phonebook) const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  phonebook_access.Select(location, phonebook);
}

BlueZObexTransferResult ObexPhonebookProxy::pull_all(
    const std::string &target_file,
    const std::map<std::string, sdbus::Variant> &filters) const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  const auto [path, props] = phonebook_access.PullAll(target_file, filters);
  return obex::transfer_result_from_dbus(path, props);
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_pull_all(
    const std::string &target_file,
    const std::map<std::string, sdbus::Variant> &filters) const {
  return glz::encode(pull_all(target_file, filters));
}

BlueZObexTransferResult ObexPhonebookProxy::pull(
    const std::string &vcard, const std::string &target_file,
    const std::map<std::string, sdbus::Variant> &filters) const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  const auto [path, props] = phonebook_access.Pull(vcard, target_file, filters);
  return obex::transfer_result_from_dbus(path, props);
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_pull(
    const std::string &vcard, const std::string &target_file,
    const std::map<std::string, sdbus::Variant> &filters) const {
  return glz::encode(pull(vcard, target_file, filters));
}

BlueZObexPhonebookEntries ObexPhonebookProxy::list(
    const std::map<std::string, sdbus::Variant> &filters) const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  return to_entries(phonebook_access.List(filters));
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_list(
    const std::map<std::string, sdbus::Variant> &filters) const {
  return glz::encode(list(filters));
}

BlueZObexPhonebookEntries ObexPhonebookProxy::search(
    const std::string &field, const std::string &value,
    const std::map<std::string, sdbus::Variant> &filters) const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  return to_entries(phonebook_access.Search(field, value, filters));
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_search(
    const std::string &field, const std::string &value,
    const std::map<std::string, sdbus::Variant> &filters) const {
  return glz::encode(search(field, value, filters));
}

uint16_t ObexPhonebookProxy::get_size() const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  return phonebook_access.GetSize();
}

void ObexPhonebookProxy::update_version() const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  phonebook_access.UpdateVersion();
}

BlueZObexFilterFields ObexPhonebookProxy::list_filter_fields() const {
  GeneratedPhonebookAccess1Proxy phonebook_access{*proxy_};
  return {.fields = phonebook_access.ListFilterFields()};
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_list_filter_fields() const {
  return glz::encode(list_filter_fields());
}

BlueZObexPhonebookProps ObexPhonebookProxy::properties() const {
  return obex::phonebook_props_from_map(
      object_path_,
      obex::get_all_properties(conn_, ObexClient::kObexService, object_path_,
                               "org.bluez.obex.PhonebookAccess1"));
}

std::vector<uint8_t> ObexPhonebookProxy::encoded_properties() const {
  return glz::encode(properties());
}
