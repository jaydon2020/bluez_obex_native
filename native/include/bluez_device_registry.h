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

class BluezDeviceRegistry {
public:
  static BlueZDevices get_devices();

private:
  using PropertiesMap = std::map<std::string, sdbus::Variant>;
  using InterfacesMap = std::map<std::string, PropertiesMap>;
  using ManagedObjectsMap = std::map<sdbus::ObjectPath, InterfacesMap>;

  static bool get_bool_property(const PropertiesMap &properties,
                                const std::string &key, bool fallback = false);
  static std::string get_string_property(const PropertiesMap &properties,
                                         const std::string &key);
  static std::vector<std::string>
  get_string_list_property(const PropertiesMap &properties,
                           const std::string &key);
};
