/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#pragma once

#include "bluez_obex_types.h"

#include <sdbus-c++/sdbus-c++.h>

#include <map>
#include <string>
#include <vector>

namespace obex {

using PropertiesMap = std::map<std::string, sdbus::Variant>;
using VariantMap = std::map<std::string, sdbus::Variant>;

VariantMap
variant_map_from_strings(const std::map<std::string, std::string> &values);
std::string variant_to_string(const sdbus::Variant &value);
std::vector<BlueZObexProperty>
variant_map_to_properties(const VariantMap &properties);
BlueZObexTransferResult transfer_result_from_dbus(const sdbus::ObjectPath &path,
                                                  const VariantMap &properties);

BlueZObexSessionProps session_props_from_map(const std::string &object_path,
                                             const PropertiesMap &properties);
BlueZObexTransferProps transfer_props_from_map(const std::string &object_path,
                                               const PropertiesMap &properties);
BlueZObexPhonebookProps
phonebook_props_from_map(const std::string &object_path,
                         const PropertiesMap &properties);
BlueZObexMessageProps message_props_from_map(const std::string &object_path,
                                             const PropertiesMap &properties);
BlueZObexMessageAccessProps
message_access_props_from_map(const std::string &object_path,
                              const PropertiesMap &properties);

PropertiesMap get_all_properties(sdbus::IConnection &conn,
                                 const std::string &service,
                                 const std::string &object_path,
                                 const std::string &interface_name);

template <typename T>
T get_property_value(const PropertiesMap &properties, const std::string &key,
                     const T &fallback = {}) {
  const auto it = properties.find(key);
  if (it == properties.end()) {
    return fallback;
  }
  try {
    return it->second.get<T>();
  } catch (...) {
    return fallback;
  }
}

} // namespace obex
