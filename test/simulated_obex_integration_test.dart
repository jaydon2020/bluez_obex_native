import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:test/test.dart';

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

      final singleTarget = '${tempDir.path}/ada.vcf';
      final single = await phonebook.pull('1.vcf', singleTarget);
      expect(await File(singleTarget).readAsString(), contains('Ada Lovelace'));

      final controlled = client.transfer(single.transferPath);
      expect((await controlled.properties()).status, 'complete');
      await controlled.suspend();
      expect((await controlled.properties()).status, 'suspended');
      await controlled.resume();
      expect((await controlled.properties()).status, 'active');
      await controlled.cancel();
      expect((await controlled.properties()).status, 'cancelled');
    });

    test('lists inbox messages, downloads one, and toggles status', () async {
      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'map',
      );
      final messageAccess = session.messageAccess;

      final folders = await messageAccess.listFolders();
      expect(folders.map((folder) => folder.name), contains('inbox'));

      final messages = await messageAccess.listMessages('telecom/msg/inbox');
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
        containsAll([
          BlueZObexEventType.session,
          BlueZObexEventType.phonebook,
          BlueZObexEventType.objectAdded,
          BlueZObexEventType.message,
          BlueZObexEventType.transfer,
        ]),
      );
      expect(
        received
            .where((event) => event.type == BlueZObexEventType.messageAccess)
            .single
            .payload,
        isA<BlueZObexMessageAccessProps>(),
      );
      expect(
        received
            .where((event) => event.type == BlueZObexEventType.objectAdded)
            .map((event) => event.payload),
        everyElement(isA<BlueZObexObjectAdded>()),
      );

      await sub.cancel();
    });

    test('covers session, phonebook, and message access operations', () async {
      expect(await client.getDevices(), isNotEmpty);
      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'map',
      );

      expect((await session.properties()).destination, 'AA:BB:CC:DD:EE:FF');
      expect(await session.capabilities(), contains('MAP'));
      expect(await session.phonebook.properties(), isNotNull);
      expect(await session.phonebook.getSize(), 2);
      expect(await session.phonebook.listFilterFields(), contains('Fields'));
      await session.phonebook.updateVersion();

      final access = session.messageAccess;
      expect((await access.properties()).supportedTypes, contains('SMS_GSM'));
      await access.setFolder('telecom/msg/inbox');
      expect(await access.listFilterFields(), contains('SubjectLength'));
      await access.updateInbox();

      final source = File('${tempDir.path}/outgoing.bmsg');
      await source.writeAsString('BEGIN:BMSG\nEND:BMSG\n');
      final pushed = await access.pushMessage(
        source.path,
        'telecom/msg/outbox',
        args: {'Recipient': '+10000000000'},
      );
      expect(pushed.transferPath, contains('/transfer'));

      await session.remove();
      expect((await client.getManagedObjects()).sessions, isEmpty);
    });

    test('rejects missing objects and permits repeated disposal', () async {
      final missing = client.session('/org/bluez/obex/client/missing');
      await expectLater(
        missing.properties(),
        throwsA(isA<BlueZObexNativeException>()),
      );
      await expectLater(
        client.transfer('/org/bluez/obex/client/missing-transfer').properties(),
        throwsA(isA<BlueZObexNativeException>()),
      );

      final session = await client.createSession('AA:BB:CC:DD:EE:FF');
      await expectLater(
        session.phonebook.pull('missing.vcf', '${tempDir.path}/missing.vcf'),
        throwsA(isA<BlueZObexNativeException>()),
      );

      await client.dispose();
      await client.dispose();
    });
  });
}
