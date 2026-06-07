import 'dart:convert';
import 'dart:typed_data';

import 'package:bluez_obex_native/src/ffi/codec.dart';
import 'package:bluez_obex_native/src/ffi/types.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper: encode a string as length-prefixed UTF-8 (matches glaze_meta.h).
void _writeString(BytesBuilder b, String s) {
  final bytes = Uint8List.fromList(utf8.encode(s));
  final len = ByteData(4)..setUint32(0, bytes.length, Endian.little);
  b.add(len.buffer.asUint8List());
  b.add(bytes);
}

void _writeBool(BytesBuilder b, bool v) {
  b.addByte(v ? 1 : 0);
}

void _writeUint8(BytesBuilder b, int v) {
  b.addByte(v);
}

void _writeUint32(BytesBuilder b, int v) {
  final d = ByteData(4)..setUint32(0, v, Endian.little);
  b.add(d.buffer.asUint8List());
}

void _writeUint64(BytesBuilder b, int v) {
  final d = ByteData(8)..setUint64(0, v, Endian.little);
  b.add(d.buffer.asUint8List());
}

void _writeProperties(BytesBuilder b, Map<String, String> properties) {
  _writeUint32(b, properties.length);
  for (final entry in properties.entries) {
    _writeString(b, entry.key);
    _writeString(b, entry.value);
  }
}

void _writeStringList(BytesBuilder b, List<String> values) {
  _writeUint32(b, values.length);
  for (final value in values) {
    _writeString(b, value);
  }
}

void _writeDevices(
  BytesBuilder b,
  List<(String address, String name, bool paired, bool connected)> devices,
) {
  _writeUint32(b, devices.length);
  for (final device in devices) {
    _writeString(b, device.$1);
    _writeString(b, device.$2);
    _writeBool(b, device.$3);
    _writeBool(b, device.$4);
  }
}

void _writePhonebookEntries(
  BytesBuilder b,
  List<(String vcard, String name)> entries,
) {
  _writeUint32(b, entries.length);
  for (final entry in entries) {
    _writeString(b, entry.$1);
    _writeString(b, entry.$2);
  }
}

void _writeMessageFolders(BytesBuilder b, List<String> folders) {
  _writeUint32(b, folders.length);
  for (final folder in folders) {
    _writeString(b, folder);
  }
}

void _writeMessageProps(BytesBuilder b) {
  _writeString(b, '/org/bluez/obex/client/session0/message0');
  _writeString(b, 'telecom/msg/inbox');
  _writeString(b, 'Status');
  _writeString(b, '20260606T123456');
  _writeString(b, 'Ada');
  _writeString(b, '+10000000000');
  _writeString(b, 'ada@example.com');
  _writeString(b, 'Grace');
  _writeString(b, '+19999999999');
  _writeString(b, 'sms-gsm');
  _writeUint64(b, 160);
  _writeBool(b, true);
  _writeString(b, 'complete');
  _writeUint64(b, 0);
  _writeBool(b, true);
  _writeBool(b, false);
  _writeBool(b, false);
  _writeBool(b, false);
  _writeBool(b, true);
}

void main() {
  group('GlazeCodec', () {
    test('decodes BlueZObexProperty', () {
      final b = BytesBuilder();
      _writeString(b, 'Status');
      _writeString(b, 'active');

      final prop = GlazeCodec.decode<BlueZObexProperty>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(prop.key, 'Status');
      expect(prop.value, 'active');
    });

    test('decodes BlueZObexSessionProps', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0');
      _writeString(b, '00:11:22:33:44:55');
      _writeString(b, 'AA:BB:CC:DD:EE:FF');
      _writeUint8(b, 12);
      _writeString(b, 'pbap');
      _writeString(b, '/telecom');

      final props = GlazeCodec.decode<BlueZObexSessionProps>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(props.objectPath, '/org/bluez/obex/client/session0');
      expect(props.source, '00:11:22:33:44:55');
      expect(props.destination, 'AA:BB:CC:DD:EE:FF');
      expect(props.channel, 12);
      expect(props.target, 'pbap');
      expect(props.root, '/telecom');
    });

    test('decodes BlueZObexTransferProps', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0/transfer0');
      _writeString(b, 'active');
      _writeString(b, '/org/bluez/obex/client/session0');
      _writeString(b, 'contacts.vcf');
      _writeString(b, 'text/x-vcard');
      _writeUint64(b, 1710000000);
      _writeUint64(b, 4096);
      _writeUint64(b, 1024);
      _writeString(b, '/tmp/contacts.vcf');

      final props = GlazeCodec.decode<BlueZObexTransferProps>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(props.objectPath, '/org/bluez/obex/client/session0/transfer0');
      expect(props.status, 'active');
      expect(props.session, '/org/bluez/obex/client/session0');
      expect(props.name, 'contacts.vcf');
      expect(props.type, 'text/x-vcard');
      expect(props.time, 1710000000);
      expect(props.size, 4096);
      expect(props.transferred, 1024);
      expect(props.filename, '/tmp/contacts.vcf');
    });

    test('decodes BlueZObexPhonebookProps', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0');
      _writeString(b, 'telecom/pb');
      _writeString(b, 'A1A2A3A4B1B2C1C2D1D2E1E2E3E4E5E6');
      _writeString(b, '00000000000000000000000000000001');
      _writeString(b, '00000000000000000000000000000002');
      _writeBool(b, true);

      final props = GlazeCodec.decode<BlueZObexPhonebookProps>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(props.objectPath, '/org/bluez/obex/client/session0');
      expect(props.folder, 'telecom/pb');
      expect(props.databaseIdentifier, 'A1A2A3A4B1B2C1C2D1D2E1E2E3E4E5E6');
      expect(props.primaryCounter, '00000000000000000000000000000001');
      expect(props.secondaryCounter, '00000000000000000000000000000002');
      expect(props.fixedImageSize, true);
    });

    test('decodes BlueZObexPhonebookEntry', () {
      final b = BytesBuilder();
      _writeString(b, '1.vcf');
      _writeString(b, 'Ada Lovelace');

      final entry = GlazeCodec.decode<BlueZObexPhonebookEntry>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(entry.vcard, '1.vcf');
      expect(entry.name, 'Ada Lovelace');
    });

    test('decodes BlueZObexPhonebookEntries', () {
      final b = BytesBuilder();
      _writePhonebookEntries(b, [
        ('1.vcf', 'Ada Lovelace'),
        ('2.vcf', 'Grace Hopper'),
      ]);

      final entries = GlazeCodec.decode<BlueZObexPhonebookEntries>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(entries.entries.length, 2);
      expect(entries.entries[0].vcard, '1.vcf');
      expect(entries.entries[0].name, 'Ada Lovelace');
      expect(entries.entries[1].vcard, '2.vcf');
      expect(entries.entries[1].name, 'Grace Hopper');
    });

    test('decodes BlueZObexMessageFolder', () {
      final b = BytesBuilder();
      _writeString(b, 'inbox');

      final folder = GlazeCodec.decode<BlueZObexMessageFolder>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(folder.name, 'inbox');
    });

    test('decodes BlueZObexMessageFolders', () {
      final b = BytesBuilder();
      _writeMessageFolders(b, ['inbox', 'sent']);

      final folders = GlazeCodec.decode<BlueZObexMessageFolders>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(folders.folders.length, 2);
      expect(folders.folders[0].name, 'inbox');
      expect(folders.folders[1].name, 'sent');
    });

    test('decodes BlueZObexMessageProps', () {
      final b = BytesBuilder();
      _writeMessageProps(b);

      final props = GlazeCodec.decode<BlueZObexMessageProps>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(props.objectPath, '/org/bluez/obex/client/session0/message0');
      expect(props.folder, 'telecom/msg/inbox');
      expect(props.subject, 'Status');
      expect(props.timestamp, '20260606T123456');
      expect(props.sender, 'Ada');
      expect(props.senderAddress, '+10000000000');
      expect(props.replyTo, 'ada@example.com');
      expect(props.recipient, 'Grace');
      expect(props.recipientAddress, '+19999999999');
      expect(props.type, 'sms-gsm');
      expect(props.size, 160);
      expect(props.text, true);
      expect(props.status, 'complete');
      expect(props.attachmentSize, 0);
      expect(props.priority, true);
      expect(props.read, false);
      expect(props.deleted, false);
      expect(props.sent, false);
      expect(props.protected, true);
    });

    test('decodes BlueZObexMessages', () {
      final b = BytesBuilder();
      _writeUint32(b, 1);
      _writeMessageProps(b);

      final messages = GlazeCodec.decode<BlueZObexMessages>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(messages.messages.length, 1);
      expect(
        messages.messages[0].objectPath,
        '/org/bluez/obex/client/session0/message0',
      );
      expect(messages.messages[0].folder, 'telecom/msg/inbox');
      expect(messages.messages[0].subject, 'Status');
      expect(messages.messages[0].type, 'sms-gsm');
      expect(messages.messages[0].size, 160);
      expect(messages.messages[0].text, true);
    });

    test('decodes BlueZObexFilterFields', () {
      final b = BytesBuilder();
      _writeStringList(b, ['Offset', 'MaxCount', 'Fields']);

      final fields = GlazeCodec.decode<BlueZObexFilterFields>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(fields.fields, ['Offset', 'MaxCount', 'Fields']);
    });

    test('decodes BlueZObexTransferResult', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0/transfer0');
      _writeProperties(b, {
        'Status': 'queued',
        'Filename': '/tmp/message.bmsg',
      });

      final result = GlazeCodec.decode<BlueZObexTransferResult>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(result.transferPath, '/org/bluez/obex/client/session0/transfer0');
      expect(result.properties.length, 2);
      expect(result.properties[0].key, 'Status');
      expect(result.properties[0].value, 'queued');
      expect(result.properties[1].key, 'Filename');
      expect(result.properties[1].value, '/tmp/message.bmsg');
    });

    test('decodes BlueZObexManagedObjects', () {
      final b = BytesBuilder();
      _writeStringList(b, ['/org/bluez/obex/client/session0']);
      _writeStringList(b, ['/org/bluez/obex/client/session0/transfer0']);
      _writeStringList(b, ['/org/bluez/obex/client/session0']);
      _writeStringList(b, ['/org/bluez/obex/client/session1']);
      _writeStringList(b, ['/org/bluez/obex/client/session1/message0']);

      final result = GlazeCodec.decode<BlueZObexManagedObjects>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(result.sessions, ['/org/bluez/obex/client/session0']);
      expect(result.transfers, ['/org/bluez/obex/client/session0/transfer0']);
      expect(result.phonebooks, ['/org/bluez/obex/client/session0']);
      expect(result.messageAccesses, ['/org/bluez/obex/client/session1']);
      expect(result.messages, ['/org/bluez/obex/client/session1/message0']);
    });

    test('decodes BlueZObexObjectRemoved', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0/transfer0');
      _writeString(b, 'org.bluez.obex.Transfer1');

      final result = GlazeCodec.decode<BlueZObexObjectRemoved>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(result.objectPath, '/org/bluez/obex/client/session0/transfer0');
      expect(result.interfaceName, 'org.bluez.obex.Transfer1');
    });

    test('decodes BlueZObexError', () {
      final b = BytesBuilder();
      _writeString(b, '/org/bluez/obex/client/session0');
      _writeString(b, 'org.bluez.obex.Error.Failed');
      _writeString(b, 'Transfer failed');

      final error = GlazeCodec.decode<BlueZObexError>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(error.objectPath, '/org/bluez/obex/client/session0');
      expect(error.name, 'org.bluez.obex.Error.Failed');
      expect(error.message, 'Transfer failed');
    });

    test('decodes BlueZDevices', () {
      final b = BytesBuilder();
      _writeDevices(b, [
        ('AA:BB:CC:DD:EE:FF', 'Pixel', true, true),
        ('11:22:33:44:55:66', 'Headset', false, false),
      ]);

      final result = GlazeCodec.decode<BlueZDevices>(
        Uint8List.fromList(b.toBytes()),
        0,
      );

      expect(result.devices.length, 2);
      expect(result.devices[0].address, 'AA:BB:CC:DD:EE:FF');
      expect(result.devices[0].name, 'Pixel');
      expect(result.devices[0].paired, true);
      expect(result.devices[0].connected, true);
      expect(result.devices[1].address, '11:22:33:44:55:66');
      expect(result.devices[1].name, 'Headset');
      expect(result.devices[1].paired, false);
      expect(result.devices[1].connected, false);
    });

    test('throws on unknown type', () {
      final data = Uint8List(0);
      expect(() => GlazeCodec.decode<int>(data, 0), throwsArgumentError);
    });

    test('throws on read overrun', () {
      final data = Uint8List.fromList([0x01, 0x02]);
      expect(
        () => GlazeCodec.decode<BlueZObexSessionProps>(data, 0),
        throwsRangeError,
      );
    });
  });
}
