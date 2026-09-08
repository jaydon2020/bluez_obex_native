#include "obex_object_manager.h"

#include "obex_proxy_utils.h"

#include <utility>

namespace {
constexpr auto kSessionIface = "org.bluez.obex.Session1";
constexpr auto kTransferIface = "org.bluez.obex.Transfer1";
constexpr auto kPhonebookIface = "org.bluez.obex.PhonebookAccess1";
constexpr auto kMessageAccessIface = "org.bluez.obex.MessageAccess1";
constexpr auto kMessageIface = "org.bluez.obex.Message1";

bool is_obex_interface(const std::string &interface_name) {
  return interface_name == kSessionIface || interface_name == kTransferIface ||
         interface_name == kPhonebookIface ||
         interface_name == kMessageAccessIface ||
         interface_name == kMessageIface;
}
} // namespace

ObexObjectManager::ObexObjectManager(sdbus::IConnection &conn,
                                     Dart_Port_DL events_port)
    : conn_(conn), events_port_(events_port) {
  root_proxy_ = sdbus::createProxy(conn_, sdbus::ServiceName{kObexService},
                                   sdbus::ObjectPath{kObexRootPath});

  root_proxy_->uponSignal("InterfacesAdded")
      .onInterface(kObjectManagerIface)
      .call([this](const sdbus::ObjectPath &object_path,
                   const InterfacesMap &interfaces) {
        on_interfaces_added(object_path, interfaces);
      });

  root_proxy_->uponSignal("InterfacesRemoved")
      .onInterface(kObjectManagerIface)
      .call([this](const sdbus::ObjectPath &object_path,
                   const std::vector<std::string> &interfaces) {
        on_interfaces_removed(object_path, interfaces);
      });
}

ObexObjectManager::~ObexObjectManager() {
  std::scoped_lock lock(mutex_);
  property_proxies_.clear();
  interfaces_by_path_.clear();
}

void ObexObjectManager::get_managed_objects() {
  std::map<sdbus::ObjectPath, InterfacesMap> objects;
  root_proxy_->callMethod("GetManagedObjects")
      .onInterface(kObjectManagerIface)
      .storeResultsTo(objects);

  for (const auto &[object_path, interfaces] : objects) {
    on_interfaces_added(object_path, interfaces);
  }
  post_sentinel(0x00);
}

void ObexObjectManager::on_interfaces_added(
    const sdbus::ObjectPath &object_path, const InterfacesMap &interfaces) {
  const std::string path = object_path;
  bool should_subscribe = false;

  for (const auto &[interface_name, properties] : interfaces) {
    if (!is_obex_interface(interface_name)) {
      continue;
    }
    {
      std::scoped_lock lock(mutex_);
      interfaces_by_path_[path][interface_name] = properties;
    }
    post_added(path, interface_name);
    should_subscribe = true;
    post_properties(path, interface_name, &properties);
  }

  if (should_subscribe) {
    subscribe_properties(path);
  }
}

void ObexObjectManager::on_interfaces_removed(
    const sdbus::ObjectPath &object_path,
    const std::vector<std::string> &interfaces) {
  const std::string path = object_path;

  for (const auto &interface_name : interfaces) {
    if (!is_obex_interface(interface_name)) {
      continue;
    }
    post_removed(path, interface_name);

    std::scoped_lock lock(mutex_);
    if (auto known = interfaces_by_path_.find(path);
        known != interfaces_by_path_.end()) {
      known->second.erase(interface_name);
      if (known->second.empty()) {
        interfaces_by_path_.erase(known);
        property_proxies_.erase(path);
      }
    }
  }
}

void ObexObjectManager::subscribe_properties(const std::string &object_path) {
  std::scoped_lock lock(mutex_);
  if (property_proxies_.contains(object_path)) {
    return;
  }

  auto proxy = sdbus::createProxy(conn_, sdbus::ServiceName{kObexService},
                                  sdbus::ObjectPath{object_path});
  proxy->uponSignal("PropertiesChanged")
      .onInterface(kPropertiesIface)
      .call([this,
             object_path](const std::string &interface_name,
                          const std::map<std::string, sdbus::Variant> &changed,
                          const std::vector<std::string> &invalidated) {
        if (!is_obex_interface(interface_name)) return;
        PropertiesMap snapshot;
        {
          std::scoped_lock lock(mutex_);
          auto known = interfaces_by_path_.find(object_path);
          if (known == interfaces_by_path_.end() ||
              !known->second.contains(interface_name)) return;
          auto &cached = known->second.at(interface_name);
          for (const auto &[key, value] : changed) cached[key] = value;
          for (const auto &key : invalidated) cached.erase(key);
          snapshot = cached;
        }
        // Publish the signal's state before any round trip: the object may
        // already be gone by the time a property request reaches the service.
        post_properties(object_path, interface_name, &snapshot);
        for (const auto &key : invalidated) {
          try {
            auto proxy = sdbus::createProxy(conn_, sdbus::ServiceName{kObexService},
                                           sdbus::ObjectPath{object_path});
            const auto value = proxy->getProperty(key).onInterface(interface_name);
            {
              std::scoped_lock lock(mutex_);
              auto known = interfaces_by_path_.find(object_path);
              if (known == interfaces_by_path_.end() ||
                  !known->second.contains(interface_name)) return;
              known->second.at(interface_name)[key] = value;
              snapshot = known->second.at(interface_name);
            }
            post_properties(object_path, interface_name, &snapshot);
          } catch (const sdbus::Error &error) {
            if (error.getName() != "org.freedesktop.DBus.Error.UnknownObject" &&
                error.getName() != "org.freedesktop.DBus.Error.UnknownInterface") {
              post_error(object_path, error.getName(), error.getMessage());
            }
          }
        }
      });

  property_proxies_[object_path] = std::move(proxy);
}

void ObexObjectManager::post_properties(const std::string &object_path,
                                        const std::string &interface_name,
                                        const PropertiesMap *properties) {
  try {
    PropertiesMap loaded;
    const PropertiesMap *props = properties;
    if (props == nullptr) {
      auto proxy = sdbus::createProxy(conn_, sdbus::ServiceName{kObexService},
                                      sdbus::ObjectPath{object_path});
      proxy->callMethod("GetAll")
          .onInterface(kPropertiesIface)
          .withArguments(interface_name)
          .storeResultsTo(loaded);
      props = &loaded;
    }

    if (interface_name == kSessionIface) {
      post_glaze(0x01, extract_session_props(object_path, *props));
    } else if (interface_name == kTransferIface) {
      post_glaze(0x02, extract_transfer_props(object_path, *props));
    } else if (interface_name == kPhonebookIface) {
      post_glaze(0x03, extract_phonebook_props(object_path, *props));
    } else if (interface_name == kMessageIface) {
      post_glaze(0x06, extract_message_props(object_path, *props));
    } else if (interface_name == kMessageAccessIface) {
      post_glaze(0x07, extract_message_access_props(object_path, *props));
    }
  } catch (const sdbus::Error &e) {
    // Silently ignore errors on objects that were removed before we could
    // fetch their properties (e.g. a Transfer1 that completed and was
    // removed between the PropertiesChanged signal and the GetAll call).
    const std::string name = e.getName();
    if (name != "org.freedesktop.DBus.Error.UnknownObject" &&
        name != "org.freedesktop.DBus.Error.UnknownInterface") {
      post_error(object_path, name, e.getMessage());
    }
  }
}

void ObexObjectManager::post_removed(const std::string &object_path,
                                     const std::string &interface_name) {
  BlueZObexObjectRemoved removed;
  removed.objectPath = object_path;
  removed.interfaceName = interface_name;
  post_glaze(0x7E, removed);
}

void ObexObjectManager::post_added(const std::string &object_path,
                                   const std::string &interface_name) {
  BlueZObexObjectAdded added;
  added.objectPath = object_path;
  added.interfaceName = interface_name;
  post_glaze(0x7D, added);
}

void ObexObjectManager::post_error(const std::string &object_path,
                                   const std::string &name,
                                   const std::string &message) {
  BlueZObexError error;
  error.objectPath = object_path;
  error.name = name;
  error.message = message;
  post_glaze(0x20, error);
}

BlueZObexSessionProps
ObexObjectManager::extract_session_props(const std::string &object_path,
                                         const PropertiesMap &props) {
  return obex::session_props_from_map(object_path, props);
}

BlueZObexTransferProps
ObexObjectManager::extract_transfer_props(const std::string &object_path,
                                          const PropertiesMap &props) {
  return obex::transfer_props_from_map(object_path, props);
}

BlueZObexPhonebookProps
ObexObjectManager::extract_phonebook_props(const std::string &object_path,
                                           const PropertiesMap &props) {
  return obex::phonebook_props_from_map(object_path, props);
}

BlueZObexMessageProps
ObexObjectManager::extract_message_props(const std::string &object_path,
                                         const PropertiesMap &props) {
  return obex::message_props_from_map(object_path, props);
}

BlueZObexMessageAccessProps
ObexObjectManager::extract_message_access_props(const std::string &object_path,
                                                const PropertiesMap &props) {
  return obex::message_access_props_from_map(object_path, props);
}

template <typename T>
void ObexObjectManager::post_glaze(uint8_t discriminator, const T &value) {
  post_bytes(discriminator, glz::encode(value));
}

void ObexObjectManager::post_bytes(uint8_t discriminator,
                                   const std::vector<uint8_t> &payload) {
  std::vector<uint8_t> message;
  message.reserve(payload.size() + 1);
  message.push_back(discriminator);
  message.insert(message.end(), payload.begin(), payload.end());

  Dart_CObject object;
  object.type = Dart_CObject_kTypedData;
  object.value.as_typed_data.type = Dart_TypedData_kUint8;
  object.value.as_typed_data.length = static_cast<intptr_t>(message.size());
  object.value.as_typed_data.values = message.data();
  Dart_PostCObject_DL(events_port_, &object);
}

void ObexObjectManager::post_sentinel(uint8_t discriminator) {
  std::vector<uint8_t> payload;
  post_bytes(discriminator, payload);
}

void ObexObjectManager::connection_failed(const std::string &message) noexcept {
  try {
    post_error("/", "org.bluez.obex.Error.Disconnected", message);
    post_sentinel(0xFF);
  } catch (...) {
    // Never let reporting failure escape the native event thread.
  }
}
