import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('simulated OBEX integration', () {
    late Directory tempDir;
    late BlueZObexClient client;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bluez_obex_sim_');
      client = await BlueZObexClient.simulated(outputDirectory: tempDir);
    });

    tearDown(() async {
      await client.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('connects, creates a session, and syncs contacts to vCard', () async {
      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'pbap',
      );

      final objects = await client.getManagedObjects();
      expect(objects.sessions, contains(session.objectPath));
      expect(objects.phonebooks, contains(session.objectPath));

      final phonebook = session.phonebook;
      await phonebook.select('int', 'pb');

      final entries = await phonebook.list(filters: {'MaxCount': 1});
      expect(entries, hasLength(1));
      expect(entries.single.name, 'Ada Lovelace');

      final target = '${tempDir.path}/contacts.vcf';
      final transfer = await phonebook.pullAll(target);
      expect(transfer.transferPath, contains('/transfer'));
      expect(await File(target).readAsString(), contains('BEGIN:VCARD'));
      expect(await File(target).readAsString(), contains('Ada Lovelace'));
    });

    test('lists inbox messages, downloads one, and toggles status', () async {
      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'map',
      );
      final messageAccess = session.messageAccess;

      final folders = await messageAccess.listFolders();
      expect(folders.map((folder) => folder.name), contains('inbox'));

      await messageAccess.setFolder('inbox');
      final messages = await messageAccess.listMessages('inbox');
      expect(messages, hasLength(1));

      final message = messages.single;
      expect(message.lastProperties?.subject, contains('simulated MAP'));

      final target = '${tempDir.path}/message.bmsg';
      final transfer = await message.get(target, attachment: false);
      expect(transfer.properties.map((prop) => prop.key), contains('Filename'));
      expect(
        await File(target).readAsString(),
        contains('Simulated text message'),
      );

      await message.setRead(true);
      expect((await message.properties()).read, isTrue);

      await message.setDeleted(true);
      expect((await message.properties()).deleted, isTrue);
    });

    test('emits object and transfer events', () async {
      final received = <BlueZObexEvent>[];
      final sub = client.events.listen(received.add);

      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'pbap',
      );
      await session.phonebook.pullAll('${tempDir.path}/contacts.vcf');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        received.map((event) => event.type),
        containsAll([BlueZObexEventType.session, BlueZObexEventType.transfer]),
      );

      await sub.cancel();
    });
  });
}
