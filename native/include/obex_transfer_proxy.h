/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

#pragma once

#include "bluez_obex_types.h"

#include <sdbus-c++/sdbus-c++.h>

#include <memory>
#include <string>
#include <vector>

class ObexTransferProxy {
public:
  ObexTransferProxy(sdbus::IConnection &conn, std::string object_path);
  ~ObexTransferProxy();

  ObexTransferProxy(const ObexTransferProxy &) = delete;
  ObexTransferProxy &operator=(const ObexTransferProxy &) = delete;

  void cancel() const;
  void suspend() const;
  void resume() const;
  BlueZObexTransferProps properties() const;
  std::vector<uint8_t> encoded_properties() const;

private:
  sdbus::IConnection &conn_;
  std::string object_path_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};
