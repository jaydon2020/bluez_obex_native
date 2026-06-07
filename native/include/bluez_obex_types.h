// bluez_obex_types.h - wire types for BlueZ OBEX-to-Dart payloads.
//
// Message discriminator byte at offset 0 in kExternalTypedData:
//   0x01 = BlueZObexSessionProps      (Session1 snapshot)
//   0x02 = BlueZObexTransferProps     (Transfer1 snapshot/change)
//   0x03 = BlueZObexPhonebookProps    (PhonebookAccess1 snapshot)
//   0x04 = BlueZObexPhonebookEntry    (PBAP listing entry/list payload)
//   0x05 = BlueZObexMessageFolder     (MAP folder listing entry/list payload)
//   0x06 = BlueZObexMessageProps      (Message1 snapshot/listing entry)
//   0x10 = BlueZObexTransferResult    (methods returning object, dict)
//   0x20 = BlueZObexError             (D-Bus/native error)
//   0x7E = BlueZObexObjectRemoved     (ObjectManager InterfacesRemoved)
//   0xFF = sentinel (stream done)

#pragma once

#include "glaze_meta.h"

#include <cstdint>
#include <string>
#include <vector>

// Shared key/value representation for D-Bus variant dictionaries normalized to
// strings before crossing the FFI boundary.
struct BlueZObexProperty {
  std::string key;
  std::string value;
};
template <> struct glz::meta<BlueZObexProperty> {
  static constexpr auto fields =
      std::make_tuple(glz::field("key", &BlueZObexProperty::key),
                      glz::field("value", &BlueZObexProperty::value));
};

// org.bluez.obex.Session1 properties.
struct BlueZObexSessionProps {
  std::string objectPath;
  std::string source;
  std::string destination;
  uint8_t channel{};
  std::string target;
  std::string root;
};
template <> struct glz::meta<BlueZObexSessionProps> {
  static constexpr auto fields = std::make_tuple(
      glz::field("objectPath", &BlueZObexSessionProps::objectPath),
      glz::field("source", &BlueZObexSessionProps::source),
      glz::field("destination", &BlueZObexSessionProps::destination),
      glz::field("channel", &BlueZObexSessionProps::channel),
      glz::field("target", &BlueZObexSessionProps::target),
      glz::field("root", &BlueZObexSessionProps::root));
};

// org.bluez.obex.Transfer1 properties.
struct BlueZObexTransferProps {
  std::string objectPath;
  std::string status;
  std::string session;
  std::string name;
  std::string type;
  uint64_t time{};
  uint64_t size{};
  uint64_t transferred{};
  std::string filename;
};
template <> struct glz::meta<BlueZObexTransferProps> {
  static constexpr auto fields = std::make_tuple(
      glz::field("objectPath", &BlueZObexTransferProps::objectPath),
      glz::field("status", &BlueZObexTransferProps::status),
      glz::field("session", &BlueZObexTransferProps::session),
      glz::field("name", &BlueZObexTransferProps::name),
      glz::field("type", &BlueZObexTransferProps::type),
      glz::field("time", &BlueZObexTransferProps::time),
      glz::field("size", &BlueZObexTransferProps::size),
      glz::field("transferred", &BlueZObexTransferProps::transferred),
      glz::field("filename", &BlueZObexTransferProps::filename));
};

// org.bluez.obex.PhonebookAccess1 properties.
struct BlueZObexPhonebookProps {
  std::string objectPath;
  std::string folder;
  std::string databaseIdentifier;
  std::string primaryCounter;
  std::string secondaryCounter;
  bool fixedImageSize{};
};
template <> struct glz::meta<BlueZObexPhonebookProps> {
  static constexpr auto fields = std::make_tuple(
      glz::field("objectPath", &BlueZObexPhonebookProps::objectPath),
      glz::field("folder", &BlueZObexPhonebookProps::folder),
      glz::field("databaseIdentifier",
                 &BlueZObexPhonebookProps::databaseIdentifier),
      glz::field("primaryCounter", &BlueZObexPhonebookProps::primaryCounter),
      glz::field("secondaryCounter",
                 &BlueZObexPhonebookProps::secondaryCounter),
      glz::field("fixedImageSize", &BlueZObexPhonebookProps::fixedImageSize));
};

// PhonebookAccess1 List/Search entry.
struct BlueZObexPhonebookEntry {
  std::string vcard;
  std::string name;
};
template <> struct glz::meta<BlueZObexPhonebookEntry> {
  static constexpr auto fields =
      std::make_tuple(glz::field("vcard", &BlueZObexPhonebookEntry::vcard),
                      glz::field("name", &BlueZObexPhonebookEntry::name));
};

// PhonebookAccess1 List/Search result.
struct BlueZObexPhonebookEntries {
  std::vector<BlueZObexPhonebookEntry> entries;
};
template <> struct glz::meta<BlueZObexPhonebookEntries> {
  static constexpr auto fields = std::make_tuple(
      glz::field("entries", &BlueZObexPhonebookEntries::entries));
};

// MessageAccess1 ListFolders entry.
struct BlueZObexMessageFolder {
  std::string name;
};
template <> struct glz::meta<BlueZObexMessageFolder> {
  static constexpr auto fields =
      std::make_tuple(glz::field("name", &BlueZObexMessageFolder::name));
};

// MessageAccess1 ListFolders result.
struct BlueZObexMessageFolders {
  std::vector<BlueZObexMessageFolder> folders;
};
template <> struct glz::meta<BlueZObexMessageFolders> {
  static constexpr auto fields =
      std::make_tuple(glz::field("folders", &BlueZObexMessageFolders::folders));
};

// org.bluez.obex.Message1 properties and MessageAccess1 ListMessages entries.
struct BlueZObexMessageProps {
  std::string objectPath;
  std::string folder;
  std::string subject;
  std::string timestamp;
  std::string sender;
  std::string senderAddress;
  std::string replyTo;
  std::string recipient;
  std::string recipientAddress;
  std::string type;
  uint64_t size{};
  bool text{};
  std::string status;
  uint64_t attachmentSize{};
  bool priority{};
  bool read{};
  bool deleted{};
  bool sent{};
  bool protected_{};
};
template <> struct glz::meta<BlueZObexMessageProps> {
  static constexpr auto fields = std::make_tuple(
      glz::field("objectPath", &BlueZObexMessageProps::objectPath),
      glz::field("folder", &BlueZObexMessageProps::folder),
      glz::field("subject", &BlueZObexMessageProps::subject),
      glz::field("timestamp", &BlueZObexMessageProps::timestamp),
      glz::field("sender", &BlueZObexMessageProps::sender),
      glz::field("senderAddress", &BlueZObexMessageProps::senderAddress),
      glz::field("replyTo", &BlueZObexMessageProps::replyTo),
      glz::field("recipient", &BlueZObexMessageProps::recipient),
      glz::field("recipientAddress", &BlueZObexMessageProps::recipientAddress),
      glz::field("type", &BlueZObexMessageProps::type),
      glz::field("size", &BlueZObexMessageProps::size),
      glz::field("text", &BlueZObexMessageProps::text),
      glz::field("status", &BlueZObexMessageProps::status),
      glz::field("attachmentSize", &BlueZObexMessageProps::attachmentSize),
      glz::field("priority", &BlueZObexMessageProps::priority),
      glz::field("read", &BlueZObexMessageProps::read),
      glz::field("deleted", &BlueZObexMessageProps::deleted),
      glz::field("sent", &BlueZObexMessageProps::sent),
      glz::field("protected", &BlueZObexMessageProps::protected_));
};

// MessageAccess1 ListMessages result.
struct BlueZObexMessages {
  std::vector<BlueZObexMessageProps> messages;
};
template <> struct glz::meta<BlueZObexMessages> {
  static constexpr auto fields =
      std::make_tuple(glz::field("messages", &BlueZObexMessages::messages));
};

// PhonebookAccess1/MessageAccess1 ListFilterFields result.
struct BlueZObexFilterFields {
  std::vector<std::string> fields;
};
template <> struct glz::meta<BlueZObexFilterFields> {
  static constexpr auto fields =
      std::make_tuple(glz::field("fields", &BlueZObexFilterFields::fields));
};

// Result from OBEX methods returning object, dict.
struct BlueZObexTransferResult {
  std::string transferPath;
  std::vector<BlueZObexProperty> properties;
};
template <> struct glz::meta<BlueZObexTransferResult> {
  static constexpr auto fields = std::make_tuple(
      glz::field("transferPath", &BlueZObexTransferResult::transferPath),
      glz::field("properties", &BlueZObexTransferResult::properties));
};

// ObjectManager query result.
struct BlueZObexManagedObjects {
  std::vector<std::string> sessions;
  std::vector<std::string> transfers;
  std::vector<std::string> phonebooks;
  std::vector<std::string> messageAccesses;
  std::vector<std::string> messages;
};
template <> struct glz::meta<BlueZObexManagedObjects> {
  static constexpr auto fields = std::make_tuple(
      glz::field("sessions", &BlueZObexManagedObjects::sessions),
      glz::field("transfers", &BlueZObexManagedObjects::transfers),
      glz::field("phonebooks", &BlueZObexManagedObjects::phonebooks),
      glz::field("messageAccesses", &BlueZObexManagedObjects::messageAccesses),
      glz::field("messages", &BlueZObexManagedObjects::messages));
};

struct BlueZObexObjectRemoved {
  std::string objectPath;
  std::string interfaceName;
};
template <> struct glz::meta<BlueZObexObjectRemoved> {
  static constexpr auto fields = std::make_tuple(
      glz::field("objectPath", &BlueZObexObjectRemoved::objectPath),
      glz::field("interfaceName", &BlueZObexObjectRemoved::interfaceName));
};

struct BlueZObexError {
  std::string objectPath;
  std::string name;
  std::string message;
};
template <> struct glz::meta<BlueZObexError> {
  static constexpr auto fields =
      std::make_tuple(glz::field("objectPath", &BlueZObexError::objectPath),
                      glz::field("name", &BlueZObexError::name),
                      glz::field("message", &BlueZObexError::message));
};
struct BlueZDevice {
  std::string address;
  std::string name;
  bool paired{};
  bool connected{};
  std::vector<std::string> uuids;
};
template <> struct glz::meta<BlueZDevice> {
  static constexpr auto fields =
      std::make_tuple(glz::field("address", &BlueZDevice::address),
                      glz::field("name", &BlueZDevice::name),
                      glz::field("paired", &BlueZDevice::paired),
                      glz::field("connected", &BlueZDevice::connected),
                      glz::field("uuids", &BlueZDevice::uuids));
};

struct BlueZDevices {
  std::vector<BlueZDevice> devices;
};
template <> struct glz::meta<BlueZDevices> {
  static constexpr auto fields =
      std::make_tuple(glz::field("devices", &BlueZDevices::devices));
};
