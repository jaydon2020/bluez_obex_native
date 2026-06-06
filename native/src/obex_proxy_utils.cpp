#include "obex_proxy_utils.h"

#include <sstream>
#include <utility>

namespace {
constexpr auto kPropertiesIface = "org.freedesktop.DBus.Properties";

std::string join_strings(const std::vector<std::string> &values) {
  std::ostringstream out;
  for (size_t i = 0; i < values.size(); ++i) {
    if (i != 0) {
      out << ",";
    }
    out << values[i];
  }
  return out.str();
}

template <typename T>
std::string integral_to_string(const sdbus::Variant &value) {
  return std::to_string(value.get<T>());
}
} // namespace

namespace obex {

std::string variant_to_string(const sdbus::Variant &value) {
  try {
    if (value.containsValueOfType<std::string>()) {
      return value.get<std::string>();
    }
    if (value.containsValueOfType<sdbus::ObjectPath>()) {
      return value.get<sdbus::ObjectPath>();
    }
    if (value.containsValueOfType<bool>()) {
      return value.get<bool>() ? "true" : "false";
    }
    if (value.containsValueOfType<uint8_t>()) {
      return integral_to_string<uint8_t>(value);
    }
    if (value.containsValueOfType<uint16_t>()) {
      return integral_to_string<uint16_t>(value);
    }
    if (value.containsValueOfType<uint32_t>()) {
      return integral_to_string<uint32_t>(value);
    }
    if (value.containsValueOfType<uint64_t>()) {
      return integral_to_string<uint64_t>(value);
    }
    if (value.containsValueOfType<int16_t>()) {
      return integral_to_string<int16_t>(value);
    }
    if (value.containsValueOfType<int32_t>()) {
      return integral_to_string<int32_t>(value);
    }
    if (value.containsValueOfType<int64_t>()) {
      return integral_to_string<int64_t>(value);
    }
    if (value.containsValueOfType<std::vector<std::string>>()) {
      return join_strings(value.get<std::vector<std::string>>());
    }
  } catch (...) {
    return {};
  }
  return value.dumpToString();
}

std::vector<BlueZObexProperty>
variant_map_to_properties(const VariantMap &properties) {
  std::vector<BlueZObexProperty> result;
  result.reserve(properties.size());
  for (const auto &[key, value] : properties) {
    result.push_back({.key = key, .value = variant_to_string(value)});
  }
  return result;
}

BlueZObexTransferResult
transfer_result_from_dbus(const sdbus::ObjectPath &path,
                          const VariantMap &properties) {
  BlueZObexTransferResult result;
  result.transferPath = path;
  result.properties = variant_map_to_properties(properties);
  return result;
}

BlueZObexSessionProps session_props_from_map(const std::string &object_path,
                                             const PropertiesMap &properties) {
  BlueZObexSessionProps session;
  session.objectPath = object_path;
  session.source = get_property_value<std::string>(properties, "Source");
  session.destination =
      get_property_value<std::string>(properties, "Destination");
  session.channel = get_property_value<uint8_t>(properties, "Channel");
  session.target = get_property_value<std::string>(properties, "Target");
  session.root = get_property_value<std::string>(properties, "Root");
  return session;
}

BlueZObexTransferProps
transfer_props_from_map(const std::string &object_path,
                        const PropertiesMap &properties) {
  BlueZObexTransferProps transfer;
  transfer.objectPath = object_path;
  transfer.status = get_property_value<std::string>(properties, "Status");
  transfer.session =
      get_property_value<sdbus::ObjectPath>(properties, "Session");
  transfer.name = get_property_value<std::string>(properties, "Name");
  transfer.type = get_property_value<std::string>(properties, "Type");
  transfer.time = get_property_value<uint64_t>(properties, "Time");
  transfer.size = get_property_value<uint64_t>(properties, "Size");
  transfer.transferred =
      get_property_value<uint64_t>(properties, "Transferred");
  transfer.filename = get_property_value<std::string>(properties, "Filename");
  return transfer;
}

BlueZObexPhonebookProps
phonebook_props_from_map(const std::string &object_path,
                         const PropertiesMap &properties) {
  BlueZObexPhonebookProps phonebook;
  phonebook.objectPath = object_path;
  phonebook.folder = get_property_value<std::string>(properties, "Folder");
  phonebook.databaseIdentifier =
      get_property_value<std::string>(properties, "DatabaseIdentifier");
  phonebook.primaryCounter =
      get_property_value<std::string>(properties, "PrimaryCounter");
  phonebook.secondaryCounter =
      get_property_value<std::string>(properties, "SecondaryCounter");
  phonebook.fixedImageSize =
      get_property_value<bool>(properties, "FixedImageSize");
  return phonebook;
}

BlueZObexMessageProps message_props_from_map(const std::string &object_path,
                                             const PropertiesMap &properties) {
  BlueZObexMessageProps message;
  message.objectPath = object_path;
  message.folder = get_property_value<std::string>(properties, "Folder");
  message.subject = get_property_value<std::string>(properties, "Subject");
  message.timestamp = get_property_value<std::string>(properties, "Timestamp");
  message.sender = get_property_value<std::string>(properties, "Sender");
  message.senderAddress =
      get_property_value<std::string>(properties, "SenderAddress");
  message.replyTo = get_property_value<std::string>(properties, "ReplyTo");
  message.recipient = get_property_value<std::string>(properties, "Recipient");
  message.recipientAddress =
      get_property_value<std::string>(properties, "RecipientAddress");
  message.type = get_property_value<std::string>(properties, "Type");
  message.size = get_property_value<uint64_t>(properties, "Size");
  message.text = get_property_value<bool>(properties, "Text");
  message.status = get_property_value<std::string>(properties, "Status");
  message.attachmentSize =
      get_property_value<uint64_t>(properties, "AttachmentSize");
  message.priority = get_property_value<bool>(properties, "Priority");
  message.read = get_property_value<bool>(properties, "Read");
  message.deleted = get_property_value<bool>(properties, "Deleted");
  message.sent = get_property_value<bool>(properties, "Sent");
  message.protected_ = get_property_value<bool>(properties, "Protected");
  return message;
}

PropertiesMap get_all_properties(sdbus::IConnection &conn,
                                 const std::string &service,
                                 const std::string &object_path,
                                 const std::string &interface_name) {
  PropertiesMap properties;
  auto proxy = sdbus::createProxy(conn, sdbus::ServiceName{service},
                                  sdbus::ObjectPath{object_path});
  proxy->callMethod("GetAll")
      .onInterface(kPropertiesIface)
      .withArguments(interface_name)
      .storeResultsTo(properties);
  return properties;
}

} // namespace obex
