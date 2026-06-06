// test_obex_types.cpp - glaze roundtrip tests for BlueZ OBEX wire structs.

#include "bluez_obex_types.h"

#include <cassert>

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

void test_message_folder_roundtrip() {
  BlueZObexMessageFolder orig{.name = "inbox"};

  auto buf = glz::encode(orig);
  BlueZObexMessageFolder decoded;
  auto end = glz::decode(buf.data(), 0, decoded);

  assert(end == buf.size());
  assert(decoded.name == orig.name);
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

} // namespace

int main() {
  test_property_roundtrip();
  test_session_props_roundtrip();
  test_transfer_props_roundtrip();
  test_phonebook_props_roundtrip();
  test_phonebook_entry_roundtrip();
  test_message_folder_roundtrip();
  test_message_props_roundtrip();
  test_transfer_result_roundtrip();
  test_object_manager_roundtrips();
  test_error_roundtrip();
  return 0;
}
