// types.dart - Dart-side mirrors for glaze-decoded BlueZ OBEX payloads.
// These match native/include/bluez_obex_types.h.

/// A string representation of a D-Bus variant property.
class BlueZObexProperty {
  final String key;
  final String value;

  const BlueZObexProperty({required this.key, required this.value});
}

/// org.bluez.obex.Session1 properties.
class BlueZObexSessionProps {
  final String objectPath;
  final String source;
  final String destination;
  final int channel;
  final int psm;
  final String target;
  final String root;

  const BlueZObexSessionProps({
    required this.objectPath,
    this.source = '',
    this.destination = '',
    this.channel = 0,
    this.psm = 0,
    this.target = '',
    this.root = '',
  });
}

/// org.bluez.obex.Transfer1 properties.
class BlueZObexTransferProps {
  final String objectPath;
  final String status;
  final String session;
  final String name;
  final String type;
  final int time;
  final int size;
  final int transferred;
  final String filename;

  const BlueZObexTransferProps({
    required this.objectPath,
    this.status = '',
    this.session = '',
    this.name = '',
    this.type = '',
    this.time = 0,
    this.size = 0,
    this.transferred = 0,
    this.filename = '',
  });
}

/// org.bluez.obex.PhonebookAccess1 properties.
class BlueZObexPhonebookProps {
  final String objectPath;
  final String folder;
  final String databaseIdentifier;
  final String primaryCounter;
  final String secondaryCounter;
  final bool fixedImageSize;

  const BlueZObexPhonebookProps({
    required this.objectPath,
    this.folder = '',
    this.databaseIdentifier = '',
    this.primaryCounter = '',
    this.secondaryCounter = '',
    this.fixedImageSize = false,
  });
}

/// PhonebookAccess1 List/Search entry.
class BlueZObexPhonebookEntry {
  final String vcard;
  final String name;

  const BlueZObexPhonebookEntry({required this.vcard, required this.name});
}

/// PhonebookAccess1 List/Search result.
class BlueZObexPhonebookEntries {
  final List<BlueZObexPhonebookEntry> entries;

  const BlueZObexPhonebookEntries({this.entries = const []});
}

/// MessageAccess1 ListFolders entry.
class BlueZObexMessageFolder {
  final String name;

  const BlueZObexMessageFolder({required this.name});
}

/// MessageAccess1 ListFolders result.
class BlueZObexMessageFolders {
  final List<BlueZObexMessageFolder> folders;

  const BlueZObexMessageFolders({this.folders = const []});
}

/// org.bluez.obex.Message1 properties and MessageAccess1 ListMessages entries.
class BlueZObexMessageProps {
  final String objectPath;
  final String folder;
  final String subject;
  final String timestamp;
  final String sender;
  final String senderAddress;
  final String replyTo;
  final String recipient;
  final String recipientAddress;
  final String type;
  final int size;
  final bool text;
  final String status;
  final int attachmentSize;
  final bool priority;
  final bool read;
  final bool deleted;
  final bool sent;
  final bool protected;
  final String deliveryStatus;
  final int conversationId;
  final String conversationName;
  final String direction;
  final String attachmentMimeTypes;

  const BlueZObexMessageProps({
    required this.objectPath,
    this.folder = '',
    this.subject = '',
    this.timestamp = '',
    this.sender = '',
    this.senderAddress = '',
    this.replyTo = '',
    this.recipient = '',
    this.recipientAddress = '',
    this.type = '',
    this.size = 0,
    this.text = false,
    this.status = '',
    this.attachmentSize = 0,
    this.priority = false,
    this.read = false,
    this.deleted = false,
    this.sent = false,
    this.protected = false,
    this.deliveryStatus = '',
    this.conversationId = 0,
    this.conversationName = '',
    this.direction = '',
    this.attachmentMimeTypes = '',
  });
}

/// org.bluez.obex.MessageAccess1 properties.
class BlueZObexMessageAccessProps {
  final String objectPath;
  final List<String> supportedTypes;

  const BlueZObexMessageAccessProps({
    required this.objectPath,
    this.supportedTypes = const [],
  });
}

/// MessageAccess1 ListMessages result.
class BlueZObexMessages {
  final List<BlueZObexMessageProps> messages;

  const BlueZObexMessages({this.messages = const []});
}

/// PhonebookAccess1/MessageAccess1 ListFilterFields result.
class BlueZObexFilterFields {
  final List<String> fields;

  const BlueZObexFilterFields({this.fields = const []});
}

/// Result from OBEX methods returning object, dict.
class BlueZObexTransferResult {
  final String transferPath;
  final List<BlueZObexProperty> properties;

  const BlueZObexTransferResult({
    required this.transferPath,
    this.properties = const [],
  });
}

/// Result of ObjectManager queries.
class BlueZObexManagedObjects {
  final List<String> sessions;
  final List<String> transfers;
  final List<String> phonebooks;
  final List<String> messageAccesses;
  final List<String> messages;

  const BlueZObexManagedObjects({
    this.sessions = const [],
    this.transfers = const [],
    this.phonebooks = const [],
    this.messageAccesses = const [],
    this.messages = const [],
  });
}

/// An OBEX interface added to the BlueZ object tree.
class BlueZObexObjectAdded {
  final String objectPath;
  final String interfaceName;

  const BlueZObexObjectAdded({
    required this.objectPath,
    required this.interfaceName,
  });
}

/// An OBEX interface removed from the BlueZ object tree.
class BlueZObexObjectRemoved {
  final String objectPath;
  final String interfaceName;

  const BlueZObexObjectRemoved({
    required this.objectPath,
    required this.interfaceName,
  });
}

/// Native or D-Bus error payload.
class BlueZObexError {
  final String objectPath;
  final String name;
  final String message;

  const BlueZObexError({
    required this.objectPath,
    required this.name,
    required this.message,
  });
}

class BlueZDevice {
  final String address;
  final String name;
  final bool paired;
  final bool connected;
  final List<String> uuids;

  const BlueZDevice({
    required this.address,
    required this.name,
    this.paired = false,
    this.connected = false,
    this.uuids = const [],
  });

  bool supportsProfileUuid(String uuid) {
    return uuids.any((candidate) => candidate.toLowerCase() == uuid);
  }
}

class BlueZDevices {
  final List<BlueZDevice> devices;

  const BlueZDevices({this.devices = const []});
}
