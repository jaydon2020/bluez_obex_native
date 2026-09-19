/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#include "obex_client.h"

#include "bluez_obex_types.h"

ObexClient::ObexClient(sdbus::IConnection &conn) : conn_(conn) {}

ObexClient::~ObexClient() = default;

std::vector<uint8_t> ObexClient::get_managed_objects() const {
  auto proxy = sdbus::createProxy(conn_, sdbus::ServiceName{kObexService},
                                  sdbus::ObjectPath{kObexRootPath});

  std::map<sdbus::ObjectPath,
           std::map<std::string, std::map<std::string, sdbus::Variant>>>
      objects;
  proxy->callMethod("GetManagedObjects")
      .onInterface(kObjectManagerIface)
      .storeResultsTo(objects);

  BlueZObexManagedObjects result;
  for (const auto &[path, interfaces] : objects) {
    if (interfaces.contains("org.bluez.obex.Session1")) {
      result.sessions.push_back(path);
    }
    if (interfaces.contains("org.bluez.obex.Transfer1")) {
      result.transfers.push_back(path);
    }
    if (interfaces.contains("org.bluez.obex.PhonebookAccess1")) {
      result.phonebooks.push_back(path);
    }
    if (interfaces.contains("org.bluez.obex.MessageAccess1")) {
      result.messageAccesses.push_back(path);
    }
    if (interfaces.contains("org.bluez.obex.Message1")) {
      result.messages.push_back(path);
    }
  }
  return glz::encode(result);
}
