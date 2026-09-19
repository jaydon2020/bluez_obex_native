/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "bluez_device_registry.h"

#include <exception>
#include <utility>

namespace {
constexpr auto kBluezService = "org.bluez";
constexpr auto kBluezRootPath = "/";
constexpr auto kDbusObjectManagerIface = "org.freedesktop.DBus.ObjectManager";
constexpr auto kBluezDeviceIface = "org.bluez.Device1";
} // namespace

BlueZDevices BluezDeviceRegistry::get_devices() {
  auto sys_conn = sdbus::createSystemBusConnection();
  auto proxy = sdbus::createProxy(*sys_conn, sdbus::ServiceName{kBluezService},
                                  sdbus::ObjectPath{kBluezRootPath});
  ManagedObjectsMap objects;
  proxy->callMethod("GetManagedObjects")
      .onInterface(kDbusObjectManagerIface)
      .storeResultsTo(objects);

  BlueZDevices result;
  for (const auto &[_, interfaces] : objects) {
    const auto device = interfaces.find(kBluezDeviceIface);
    if (device == interfaces.end()) {
      continue;
    }

    const auto &properties = device->second;
    auto address = get_string_property(properties, "Address");
    if (address.empty()) {
      continue;
    }

    auto name = get_string_property(properties, "Alias");
    if (name.empty()) {
      name = get_string_property(properties, "Name");
    }
    if (name.empty()) {
      name = address;
    }

    result.devices.push_back(
        {.address = std::move(address),
         .name = std::move(name),
         .paired = get_bool_property(properties, "Paired"),
         .connected = get_bool_property(properties, "Connected"),
         .uuids = get_string_list_property(properties, "UUIDs")});
  }
  return result;
}

bool BluezDeviceRegistry::get_bool_property(const PropertiesMap &properties,
                                            const std::string &key,
                                            bool fallback) {
  const auto it = properties.find(key);
  if (it == properties.end()) {
    return fallback;
  }
  try {
    return it->second.get<bool>();
  } catch (const std::exception &) {
    return fallback;
  }
}

std::string
BluezDeviceRegistry::get_string_property(const PropertiesMap &properties,
                                         const std::string &key) {
  const auto it = properties.find(key);
  if (it == properties.end()) {
    return {};
  }
  try {
    return it->second.get<std::string>();
  } catch (const std::exception &) {
    return {};
  }
}

std::vector<std::string>
BluezDeviceRegistry::get_string_list_property(const PropertiesMap &properties,
                                              const std::string &key) {
  const auto it = properties.find(key);
  if (it == properties.end()) {
    return {};
  }
  try {
    return it->second.get<std::vector<std::string>>();
  } catch (const std::exception &) {
    return {};
  }
}
