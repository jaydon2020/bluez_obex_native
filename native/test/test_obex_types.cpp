/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// test_obex_types.cpp - glaze roundtrip tests for BlueZ OBEX wire structs.

#include "bluez_obex_types.h"
#include "obex_object_manager.h"
#include "obex_proxy_utils.h"

#include <cassert>
#include <stdexcept>

namespace {

void test_property_roundtrip() {
  BlueZObexProperty orig{.key = "Status", .value = "active"};

  auto buf = glz::encode(orig);
  BlueZObexProperty decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.key == orig.key);
  assert(decoded.value == orig.value);
}

void test_session_props_roundtrip() {
  BlueZObexSessionProps orig;
  orig.objectPath = "/org/bluez/obex/client/session0";
  orig.source = "00:11:22:33:44:55";
  orig.destination = "AA:BB:CC:DD:EE:FF";
  orig.channel = 12;
  orig.psm = 0x1001;
  orig.target = "pbap";
  orig.root = "/telecom";

  auto buf = glz::encode(orig);
  BlueZObexSessionProps decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.source == orig.source);
  assert(decoded.destination == orig.destination);
  assert(decoded.channel == orig.channel);
  assert(decoded.psm == orig.psm);
  assert(decoded.target == orig.target);
  assert(decoded.root == orig.root);
}

void test_transfer_props_roundtrip() {
  BlueZObexTransferProps orig;
  orig.objectPath = "/org/bluez/obex/client/session0/transfer0";
  orig.status = "active";
  orig.session = "/org/bluez/obex/client/session0";
  orig.name = "contacts.vcf";
  orig.type = "text/x-vcard";
  orig.time = 1710000000;
  orig.size = 4096;
  orig.transferred = 1024;
  orig.filename = "/tmp/contacts.vcf";

  auto buf = glz::encode(orig);
  BlueZObexTransferProps decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.status == orig.status);
  assert(decoded.session == orig.session);
  assert(decoded.name == orig.name);
  assert(decoded.type == orig.type);
  assert(decoded.time == orig.time);
  assert(decoded.size == orig.size);
  assert(decoded.transferred == orig.transferred);
  assert(decoded.filename == orig.filename);
}

void test_phonebook_props_roundtrip() {
  BlueZObexPhonebookProps orig;
  orig.objectPath = "/org/bluez/obex/client/session0";
  orig.folder = "telecom/pb";
  orig.databaseIdentifier = "A1A2A3A4B1B2C1C2D1D2E1E2E3E4E5E6";
  orig.primaryCounter = "00000000000000000000000000000001";
  orig.secondaryCounter = "00000000000000000000000000000002";
  orig.fixedImageSize = true;

  auto buf = glz::encode(orig);
  BlueZObexPhonebookProps decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.folder == orig.folder);
  assert(decoded.databaseIdentifier == orig.databaseIdentifier);
  assert(decoded.primaryCounter == orig.primaryCounter);
  assert(decoded.secondaryCounter == orig.secondaryCounter);
  assert(decoded.fixedImageSize == orig.fixedImageSize);
}

void test_phonebook_entry_roundtrip() {
  BlueZObexPhonebookEntry orig;
  orig.vcard = "1.vcf";
  orig.name = "Ada Lovelace";

  auto buf = glz::encode(orig);
  BlueZObexPhonebookEntry decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.vcard == orig.vcard);
  assert(decoded.name == orig.name);
}

void test_phonebook_entries_roundtrip() {
  BlueZObexPhonebookEntries orig;
  orig.entries = {{"1.vcf", "Ada Lovelace"}, {"2.vcf", "Grace Hopper"}};

  auto buf = glz::encode(orig);
  BlueZObexPhonebookEntries decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.entries.size() == 2u);
  assert(decoded.entries[0].vcard == "1.vcf");
  assert(decoded.entries[0].name == "Ada Lovelace");
  assert(decoded.entries[1].vcard == "2.vcf");
  assert(decoded.entries[1].name == "Grace Hopper");
}

void test_message_folder_roundtrip() {
  BlueZObexMessageFolder orig{.name = "inbox"};

  auto buf = glz::encode(orig);
  BlueZObexMessageFolder decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.name == orig.name);
}

void test_message_folders_roundtrip() {
  BlueZObexMessageFolders orig;
  orig.folders = {{"inbox"}, {"sent"}};

  auto buf = glz::encode(orig);
  BlueZObexMessageFolders decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.folders.size() == 2u);
  assert(decoded.folders[0].name == "inbox");
  assert(decoded.folders[1].name == "sent");
}

void test_message_props_roundtrip() {
  BlueZObexMessageProps orig;
  orig.objectPath = "/org/bluez/obex/client/session0/message0";
  orig.folder = "telecom/msg/inbox";
  orig.subject = "Status";
  orig.timestamp = "20260606T123456";
  orig.sender = "Ada";
  orig.senderAddress = "+10000000000";
  orig.replyTo = "ada@example.com";
  orig.recipient = "Grace";
  orig.recipientAddress = "+19999999999";
  orig.type = "sms-gsm";
  orig.size = 160;
  orig.text = true;
  orig.status = "complete";
  orig.attachmentSize = 0;
  orig.priority = true;
  orig.read = false;
  orig.deleted = false;
  orig.sent = false;
  orig.protected_ = true;
  orig.deliveryStatus = "delivered";
  orig.conversationId = 42;
  orig.conversationName = "Project";
  orig.direction = "incoming";
  orig.attachmentMimeTypes = "image/jpeg";

  auto buf = glz::encode(orig);
  BlueZObexMessageProps decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.folder == orig.folder);
  assert(decoded.subject == orig.subject);
  assert(decoded.timestamp == orig.timestamp);
  assert(decoded.sender == orig.sender);
  assert(decoded.senderAddress == orig.senderAddress);
  assert(decoded.replyTo == orig.replyTo);
  assert(decoded.recipient == orig.recipient);
  assert(decoded.recipientAddress == orig.recipientAddress);
  assert(decoded.type == orig.type);
  assert(decoded.size == orig.size);
  assert(decoded.text == orig.text);
  assert(decoded.status == orig.status);
  assert(decoded.attachmentSize == orig.attachmentSize);
  assert(decoded.priority == orig.priority);
  assert(decoded.read == orig.read);
  assert(decoded.deleted == orig.deleted);
  assert(decoded.sent == orig.sent);
  assert(decoded.protected_ == orig.protected_);
  assert(decoded.deliveryStatus == orig.deliveryStatus);
  assert(decoded.conversationId == orig.conversationId);
  assert(decoded.conversationName == orig.conversationName);
  assert(decoded.direction == orig.direction);
  assert(decoded.attachmentMimeTypes == orig.attachmentMimeTypes);
}

void test_message_list_roundtrip() {
  BlueZObexMessageProps message;
  message.objectPath = "/org/bluez/obex/client/session0/message0";
  message.folder = "telecom/msg/inbox";
  message.subject = "Status";
  message.type = "sms-gsm";
  message.size = 160;
  message.text = true;
  message.status = "complete";

  BlueZObexMessages orig;
  orig.messages = {message};

  auto buf = glz::encode(orig);
  BlueZObexMessages decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.messages.size() == 1u);
  assert(decoded.messages[0].objectPath == message.objectPath);
  assert(decoded.messages[0].folder == message.folder);
  assert(decoded.messages[0].subject == message.subject);
  assert(decoded.messages[0].type == message.type);
  assert(decoded.messages[0].size == message.size);
  assert(decoded.messages[0].text == message.text);
  assert(decoded.messages[0].status == message.status);
}

void test_message_access_props_roundtrip() {
  BlueZObexMessageAccessProps orig;
  orig.objectPath = "/org/bluez/obex/client/session0";
  orig.supportedTypes = {"EMAIL", "SMS_GSM", "MMS"};

  auto buf = glz::encode(orig);
  BlueZObexMessageAccessProps decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.supportedTypes == orig.supportedTypes);
}

void test_filter_fields_roundtrip() {
  BlueZObexFilterFields orig;
  orig.fields = {"Offset", "MaxCount", "Fields"};

  auto buf = glz::encode(orig);
  BlueZObexFilterFields decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.fields == orig.fields);
}

void test_transfer_result_roundtrip() {
  BlueZObexTransferResult orig;
  orig.transferPath = "/org/bluez/obex/client/session0/transfer0";
  orig.properties = {{"Status", "queued"}, {"Filename", "/tmp/message.bmsg"}};

  auto buf = glz::encode(orig);
  BlueZObexTransferResult decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.transferPath == orig.transferPath);
  assert(decoded.properties.size() == 2u);
  assert(decoded.properties[0].key == "Status");
  assert(decoded.properties[0].value == "queued");
  assert(decoded.properties[1].key == "Filename");
  assert(decoded.properties[1].value == "/tmp/message.bmsg");
}

void test_object_manager_roundtrips() {
  BlueZObexManagedObjects objects;
  objects.sessions = {"/org/bluez/obex/client/session0"};
  objects.transfers = {"/org/bluez/obex/client/session0/transfer0"};
  objects.phonebooks = {"/org/bluez/obex/client/session0"};
  objects.messageAccesses = {"/org/bluez/obex/client/session1"};
  objects.messages = {"/org/bluez/obex/client/session1/message0"};

  auto objects_buf = glz::encode(objects);
  BlueZObexManagedObjects decoded_objects;
  auto objects_end = glz::decode(objects_buf.data(), 0, decoded_objects);

  assert(objects_end == objects_buf.size());
  assert(decoded_objects.sessions == objects.sessions);
  assert(decoded_objects.transfers == objects.transfers);
  assert(decoded_objects.phonebooks == objects.phonebooks);
  assert(decoded_objects.messageAccesses == objects.messageAccesses);
  assert(decoded_objects.messages == objects.messages);

  BlueZObexObjectRemoved removed;
  removed.objectPath = "/org/bluez/obex/client/session0/transfer0";
  removed.interfaceName = "org.bluez.obex.Transfer1";

  auto removed_buf = glz::encode(removed);
  BlueZObexObjectRemoved decoded_removed;
  auto removed_end = glz::decode(removed_buf.data(), 0, decoded_removed);

  assert(removed_end == removed_buf.size());
  assert(decoded_removed.objectPath == removed.objectPath);
  assert(decoded_removed.interfaceName == removed.interfaceName);

  BlueZObexObjectAdded added;
  added.objectPath = "/org/bluez/obex/client/session0";
  added.interfaceName = "org.bluez.obex.MessageAccess1";

  auto added_buf = glz::encode(added);
  BlueZObexObjectAdded decoded_added;
  auto added_end = glz::decode(added_buf.data(), 0, decoded_added);

  assert(added_end == added_buf.size());
  assert(decoded_added.objectPath == added.objectPath);
  assert(decoded_added.interfaceName == added.interfaceName);
}

void test_devices_roundtrip() {
  BlueZDevices orig;
  orig.devices = {
      {.address = "AA:BB:CC:DD:EE:FF",
       .name = "Pixel",
       .paired = true,
       .connected = true,
       .uuids = {"0000112f-0000-1000-8000-00805f9b34fb"}},
      {.address = "11:22:33:44:55:66",
       .name = "Headset",
       .paired = false,
       .connected = false,
       .uuids = {}},
  };

  auto buf = glz::encode(orig);
  BlueZDevices decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.devices.size() == 2u);
  assert(decoded.devices[0].address == "AA:BB:CC:DD:EE:FF");
  assert(decoded.devices[0].name == "Pixel");
  assert(decoded.devices[0].paired);
  assert(decoded.devices[0].connected);
  assert(decoded.devices[0].uuids.size() == 1u);
  assert(decoded.devices[0].uuids[0] == "0000112f-0000-1000-8000-00805f9b34fb");
  assert(decoded.devices[1].address == "11:22:33:44:55:66");
  assert(decoded.devices[1].name == "Headset");
  assert(!decoded.devices[1].paired);
  assert(!decoded.devices[1].connected);
  assert(decoded.devices[1].uuids.empty());
}

void test_error_roundtrip() {
  BlueZObexError orig;
  orig.objectPath = "/org/bluez/obex/client/session0";
  orig.name = "org.bluez.obex.Error.Failed";
  orig.message = "Transfer failed";

  auto buf = glz::encode(orig);
  BlueZObexError decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.objectPath == orig.objectPath);
  assert(decoded.name == orig.name);
  assert(decoded.message == orig.message);
}

void test_object_manager_extract_session_props() {
  ObexObjectManager::PropertiesMap props;
  props["Source"] = sdbus::Variant{std::string{"00:11:22:33:44:55"}};
  props["Destination"] = sdbus::Variant{std::string{"AA:BB:CC:DD:EE:FF"}};
  props["Channel"] = sdbus::Variant{uint8_t{12}};
  props["Target"] = sdbus::Variant{std::string{"pbap"}};
  props["Root"] = sdbus::Variant{std::string{"/telecom"}};

  auto session = ObexObjectManager::extract_session_props(
      "/org/bluez/obex/client/session0", props);

  assert(session.objectPath == "/org/bluez/obex/client/session0");
  assert(session.source == "00:11:22:33:44:55");
  assert(session.destination == "AA:BB:CC:DD:EE:FF");
  assert(session.channel == 12);
  assert(session.target == "pbap");
  assert(session.root == "/telecom");
}

void test_object_manager_extract_transfer_props() {
  ObexObjectManager::PropertiesMap props;
  props["Status"] = sdbus::Variant{std::string{"active"}};
  props["Session"] =
      sdbus::Variant{sdbus::ObjectPath{"/org/bluez/obex/client/session0"}};
  props["Name"] = sdbus::Variant{std::string{"contacts.vcf"}};
  props["Type"] = sdbus::Variant{std::string{"text/x-vcard"}};
  props["Time"] = sdbus::Variant{uint64_t{1710000000}};
  props["Size"] = sdbus::Variant{uint64_t{4096}};
  props["Transferred"] = sdbus::Variant{uint64_t{1024}};
  props["Filename"] = sdbus::Variant{std::string{"/tmp/contacts.vcf"}};

  auto transfer = ObexObjectManager::extract_transfer_props(
      "/org/bluez/obex/client/session0/transfer0", props);

  assert(transfer.objectPath == "/org/bluez/obex/client/session0/transfer0");
  assert(transfer.status == "active");
  assert(transfer.session == "/org/bluez/obex/client/session0");
  assert(transfer.name == "contacts.vcf");
  assert(transfer.type == "text/x-vcard");
  assert(transfer.time == 1710000000);
  assert(transfer.size == 4096);
  assert(transfer.transferred == 1024);
  assert(transfer.filename == "/tmp/contacts.vcf");
}

void test_object_manager_extract_profile_props() {
  ObexObjectManager::PropertiesMap phonebook_props;
  phonebook_props["Folder"] = sdbus::Variant{std::string{"telecom/pb"}};
  phonebook_props["FixedImageSize"] = sdbus::Variant{true};
  const auto phonebook = ObexObjectManager::extract_phonebook_props(
      "/org/bluez/obex/client/session0", phonebook_props);
  assert(phonebook.folder == "telecom/pb");
  assert(phonebook.fixedImageSize);

  ObexObjectManager::PropertiesMap message_props;
  message_props["Subject"] = sdbus::Variant{std::string{"Hello"}};
  message_props["Read"] = sdbus::Variant{true};
  const auto message = ObexObjectManager::extract_message_props(
      "/org/bluez/obex/client/session0/message0", message_props);
  assert(message.subject == "Hello");
  assert(message.read);

  ObexObjectManager::PropertiesMap message_access_props;
  message_access_props["SupportedTypes"] =
      sdbus::Variant{std::vector<std::string>{"EMAIL", "SMS_GSM"}};
  const auto message_access = ObexObjectManager::extract_message_access_props(
      "/org/bluez/obex/client/session0", message_access_props);
  assert(message_access.supportedTypes.size() == 2u);
  assert(message_access.supportedTypes[1] == "SMS_GSM");
}

void test_proxy_utils_variant_conversion() {
  obex::VariantMap props;
  props["Filename"] = sdbus::Variant{std::string{"/tmp/message.bmsg"}};
  props["Size"] = sdbus::Variant{uint64_t{4096}};
  props["Visible"] = sdbus::Variant{true};
  props["Path"] =
      sdbus::Variant{sdbus::ObjectPath{"/org/bluez/obex/client/session0"}};

  const auto normalized = obex::variant_map_to_properties(props);

  assert(normalized.size() == 4u);
  assert(normalized[0].key == "Filename");
  assert(normalized[0].value == "/tmp/message.bmsg");
  assert(normalized[1].key == "Path");
  assert(normalized[1].value == "/org/bluez/obex/client/session0");
  assert(normalized[2].key == "Size");
  assert(normalized[2].value == "4096");
  assert(normalized[3].key == "Visible");
  assert(normalized[3].value == "true");
}

void test_proxy_utils_filter_conversion() {
  const auto filters =
      obex::variant_map_from_strings({{"MaxCount", "50"},
                                      {"SubjectLength", "120"},
                                      {"Fields", "subject,sender"},
                                      {"FilterAny", "TEL,EMAIL"},
                                      {"Types", "sms,email"},
                                      {"Read", "true"},
                                      {"Format", "vcard30"}});

  assert(filters.at("MaxCount").get<uint16_t>() == 50);
  assert(filters.at("SubjectLength").get<uint8_t>() == 120);
  assert(filters.at("Fields").get<std::vector<std::string>>().size() == 2u);
  assert(filters.at("FilterAny").get<std::vector<std::string>>()[1] == "EMAIL");
  assert(filters.at("Types").get<std::vector<std::string>>()[0] == "sms");
  assert(filters.at("Read").get<bool>());
  assert(filters.at("Format").get<std::string>() == "vcard30");

  bool invalid_number_rejected = false;
  try {
    (void)obex::variant_map_from_strings({{"MaxCount", "-1"}});
  } catch (const std::invalid_argument &) {
    invalid_number_rejected = true;
  }
  assert(invalid_number_rejected);

  bool invalid_bool_rejected = false;
  try {
    (void)obex::variant_map_from_strings({{"Read", "yes"}});
  } catch (const std::invalid_argument &) {
    invalid_bool_rejected = true;
  }
  assert(invalid_bool_rejected);
}

void test_proxy_utils_extract_phonebook_props() {
  obex::PropertiesMap props;
  props["Folder"] = sdbus::Variant{std::string{"telecom/pb"}};
  props["DatabaseIdentifier"] =
      sdbus::Variant{std::string{"A1A2A3A4B1B2C1C2D1D2E1E2E3E4E5E6"}};
  props["PrimaryCounter"] =
      sdbus::Variant{std::string{"00000000000000000000000000000001"}};
  props["SecondaryCounter"] =
      sdbus::Variant{std::string{"00000000000000000000000000000002"}};
  props["FixedImageSize"] = sdbus::Variant{true};

  auto phonebook =
      obex::phonebook_props_from_map("/org/bluez/obex/client/session0", props);

  assert(phonebook.objectPath == "/org/bluez/obex/client/session0");
  assert(phonebook.folder == "telecom/pb");
  assert(phonebook.databaseIdentifier == "A1A2A3A4B1B2C1C2D1D2E1E2E3E4E5E6");
  assert(phonebook.primaryCounter == "00000000000000000000000000000001");
  assert(phonebook.secondaryCounter == "00000000000000000000000000000002");
  assert(phonebook.fixedImageSize);
}

void test_proxy_utils_extract_message_props() {
  obex::PropertiesMap props;
  props["Folder"] = sdbus::Variant{std::string{"telecom/msg/inbox"}};
  props["Subject"] = sdbus::Variant{std::string{"Status"}};
  props["Timestamp"] = sdbus::Variant{std::string{"20260606T123456"}};
  props["Sender"] = sdbus::Variant{std::string{"Ada"}};
  props["SenderAddress"] = sdbus::Variant{std::string{"+10000000000"}};
  props["ReplyTo"] = sdbus::Variant{std::string{"ada@example.com"}};
  props["Recipient"] = sdbus::Variant{std::string{"Grace"}};
  props["RecipientAddress"] = sdbus::Variant{std::string{"+19999999999"}};
  props["Type"] = sdbus::Variant{std::string{"sms-gsm"}};
  props["Size"] = sdbus::Variant{uint64_t{160}};
  props["Text"] = sdbus::Variant{true};
  props["Status"] = sdbus::Variant{std::string{"complete"}};
  props["AttachmentSize"] = sdbus::Variant{uint64_t{12}};
  props["Priority"] = sdbus::Variant{true};
  props["Read"] = sdbus::Variant{false};
  props["Deleted"] = sdbus::Variant{false};
  props["Sent"] = sdbus::Variant{false};
  props["Protected"] = sdbus::Variant{true};

  auto message = obex::message_props_from_map(
      "/org/bluez/obex/client/session0/message0", props);

  assert(message.objectPath == "/org/bluez/obex/client/session0/message0");
  assert(message.folder == "telecom/msg/inbox");
  assert(message.subject == "Status");
  assert(message.timestamp == "20260606T123456");
  assert(message.sender == "Ada");
  assert(message.senderAddress == "+10000000000");
  assert(message.replyTo == "ada@example.com");
  assert(message.recipient == "Grace");
  assert(message.recipientAddress == "+19999999999");
  assert(message.type == "sms-gsm");
  assert(message.size == 160);
  assert(message.text);
  assert(message.status == "complete");
  assert(message.attachmentSize == 12);
  assert(message.priority);
  assert(!message.read);
  assert(!message.deleted);
  assert(!message.sent);
  assert(message.protected_);
}

} // namespace

int main() {
  test_property_roundtrip();
  test_session_props_roundtrip();
  test_transfer_props_roundtrip();
  test_phonebook_props_roundtrip();
  test_phonebook_entry_roundtrip();
  test_phonebook_entries_roundtrip();
  test_message_folder_roundtrip();
  test_message_folders_roundtrip();
  test_message_props_roundtrip();
  test_message_list_roundtrip();
  test_message_access_props_roundtrip();
  test_filter_fields_roundtrip();
  test_transfer_result_roundtrip();
  test_object_manager_roundtrips();
  test_devices_roundtrip();
  test_error_roundtrip();
  test_object_manager_extract_session_props();
  test_object_manager_extract_transfer_props();
  test_object_manager_extract_profile_props();
  test_proxy_utils_variant_conversion();
  test_proxy_utils_filter_conversion();
  test_proxy_utils_extract_phonebook_props();
  test_proxy_utils_extract_message_props();
  return 0;
}
