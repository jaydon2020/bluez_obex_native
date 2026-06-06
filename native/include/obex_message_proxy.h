#pragma once

#include "bluez_obex_types.h"

#include <sdbus-c++/sdbus-c++.h>

#include <map>
#include <memory>
#include <string>
#include <vector>

class ObexMessageAccessProxy {
public:
  ObexMessageAccessProxy(sdbus::IConnection &conn, std::string object_path);
  ~ObexMessageAccessProxy();

  ObexMessageAccessProxy(const ObexMessageAccessProxy &) = delete;
  ObexMessageAccessProxy &operator=(const ObexMessageAccessProxy &) = delete;

  void set_folder(const std::string &name) const;
  BlueZObexMessageFolders
  list_folders(const std::map<std::string, sdbus::Variant> &filter = {}) const;
  std::vector<uint8_t> encoded_list_folders(
      const std::map<std::string, sdbus::Variant> &filter = {}) const;
  BlueZObexFilterFields list_filter_fields() const;
  std::vector<uint8_t> encoded_list_filter_fields() const;
  BlueZObexMessages
  list_messages(const std::string &folder,
                const std::map<std::string, sdbus::Variant> &filter = {}) const;
  std::vector<uint8_t> encoded_list_messages(
      const std::string &folder,
      const std::map<std::string, sdbus::Variant> &filter = {}) const;
  void update_inbox() const;
  BlueZObexTransferResult
  push_message(const std::string &source_file, const std::string &folder,
               const std::map<std::string, sdbus::Variant> &args = {}) const;

private:
  sdbus::IConnection &conn_;
  std::string object_path_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};

class ObexMessageProxy {
public:
  ObexMessageProxy(sdbus::IConnection &conn, std::string object_path);
  ~ObexMessageProxy();

  ObexMessageProxy(const ObexMessageProxy &) = delete;
  ObexMessageProxy &operator=(const ObexMessageProxy &) = delete;

  BlueZObexTransferResult get(const std::string &target_file,
                              bool attachment) const;
  std::vector<uint8_t> encoded_get(const std::string &target_file,
                                   bool attachment) const;
  void set_read(bool read) const;
  void set_deleted(bool deleted) const;
  BlueZObexMessageProps properties() const;
  std::vector<uint8_t> encoded_properties() const;

private:
  sdbus::IConnection &conn_;
  std::string object_path_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};
