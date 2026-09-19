/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "obex_proxy_utils.h"

#include <charconv>
#include <sstream>
#include <stdexcept>
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

bool parse_uint16(const std::string &value, uint16_t &out) {
  uint32_t parsed{};
  const auto *begin = value.data();
  const auto *end = value.data() + value.size();
  const auto [ptr, ec] = std::from_chars(begin, end, parsed);
  if (ec != std::errc{} || ptr != end || parsed > UINT16_MAX) {
    return false;
  }
  out = static_cast<uint16_t>(parsed);
  return true;
}

bool parse_uint8(const std::string &value, uint8_t &out) {
  uint16_t parsed{};
  if (!parse_uint16(value, parsed) || parsed > UINT8_MAX) {
    return false;
  }
  out = static_cast<uint8_t>(parsed);
  return true;
}

std::vector<std::string> split_csv(const std::string &value) {
  std::vector<std::string> result;
  size_t start = 0;
  while (start <= value.size()) {
    const auto comma = value.find(',', start);
    const auto end = comma == std::string::npos ? value.size() : comma;
    if (end > start) {
      result.push_back(value.substr(start, end - start));
    }
    if (comma == std::string::npos) {
      break;
    }
    start = comma + 1;
  }
  return result;
}

bool is_uint16_key(const std::string &key) {
  return key == "MaxCount" || key == "Offset" || key == "ListStartOffset" ||
         key == "StartOffset";
}

bool is_string_array_key(const std::string &key) {
  return key == "Fields" || key == "Filter" || key == "FilterAll" ||
         key == "FilterAny" || key == "Types";
}

bool is_bool_key(const std::string &key) {
  return key == "ResetNewMissedCalls" || key == "Read" || key == "Priority" ||
         key == "Transparent" || key == "Retry";
}
} // namespace

namespace obex {

VariantMap
variant_map_from_strings(const std::map<std::string, std::string> &values) {
  VariantMap result;
  for (const auto &[key, value] : values) {
    if (key.empty()) {
      continue;
    }

    uint16_t parsed_uint16{};
    uint8_t parsed_uint8{};
    if (is_uint16_key(key)) {
      if (!parse_uint16(value, parsed_uint16)) {
        throw std::invalid_argument(key + " must be a uint16");
      }
      result[key] = sdbus::Variant{parsed_uint16};
    } else if (key == "SubjectLength") {
      if (!parse_uint8(value, parsed_uint8)) {
        throw std::invalid_argument(key + " must be a uint8");
      }
      result[key] = sdbus::Variant{parsed_uint8};
    } else if (is_string_array_key(key)) {
      result[key] = sdbus::Variant{split_csv(value)};
    } else if (is_bool_key(key)) {
      if (value != "true" && value != "false") {
        throw std::invalid_argument(key + " must be a bool");
      }
      result[key] = sdbus::Variant{value == "true"};
    } else {
      result[key] = sdbus::Variant{value};
    }
  }
  return result;
}

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
  session.psm = get_property_value<uint16_t>(properties, "PSM");
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
  message.deliveryStatus =
      get_property_value<std::string>(properties, "DeliveryStatus");
  message.conversationId =
      get_property_value<uint64_t>(properties, "ConversationId");
  message.conversationName =
      get_property_value<std::string>(properties, "ConversationName");
  message.direction = get_property_value<std::string>(properties, "Direction");
  message.attachmentMimeTypes =
      get_property_value<std::string>(properties, "AttachmentMimeTypes");
  return message;
}

BlueZObexMessageAccessProps
message_access_props_from_map(const std::string &object_path,
                              const PropertiesMap &properties) {
  BlueZObexMessageAccessProps message_access;
  message_access.objectPath = object_path;
  message_access.supportedTypes = get_property_value<std::vector<std::string>>(
      properties, "SupportedTypes");
  return message_access;
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
