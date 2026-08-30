#pragma once

#include "bluez_obex_types.h"

#include <sdbus-c++/sdbus-c++.h>

#include <cstdint>
#include <map>
#include <memory>
#include <string>
#include <vector>

class ObexPhonebookProxy {
public:
  ObexPhonebookProxy(sdbus::IConnection &conn, std::string object_path);
  ~ObexPhonebookProxy();

  ObexPhonebookProxy(const ObexPhonebookProxy &) = delete;
  ObexPhonebookProxy &operator=(const ObexPhonebookProxy &) = delete;

  void select(const std::string &location, const std::string &phonebook) const;
  BlueZObexTransferResult
  pull_all(const std::string &target_file,
           const std::map<std::string, sdbus::Variant> &filters = {}) const;
  std::vector<uint8_t> encoded_pull_all(
      const std::string &target_file,
      const std::map<std::string, sdbus::Variant> &filters = {}) const;
  BlueZObexTransferResult
  pull(const std::string &vcard, const std::string &target_file,
       const std::map<std::string, sdbus::Variant> &filters = {}) const;
  std::vector<uint8_t>
  encoded_pull(const std::string &vcard, const std::string &target_file,
               const std::map<std::string, sdbus::Variant> &filters = {}) const;
  BlueZObexPhonebookEntries
  list(const std::map<std::string, sdbus::Variant> &filters = {}) const;
  std::vector<uint8_t>
  encoded_list(const std::map<std::string, sdbus::Variant> &filters = {}) const;
  BlueZObexPhonebookEntries
  search(const std::string &field, const std::string &value,
         const std::map<std::string, sdbus::Variant> &filters = {}) const;
  std::vector<uint8_t> encoded_search(
      const std::string &field, const std::string &value,
      const std::map<std::string, sdbus::Variant> &filters = {}) const;
  uint16_t get_size() const;
  void update_version() const;
  BlueZObexFilterFields list_filter_fields() const;
  std::vector<uint8_t> encoded_list_filter_fields() const;
  BlueZObexPhonebookProps properties() const;
  std::vector<uint8_t> encoded_properties() const;

private:
  sdbus::IConnection &conn_;
  std::string object_path_;
  std::unique_ptr<sdbus::IProxy> proxy_;
};
