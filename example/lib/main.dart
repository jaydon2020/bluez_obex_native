import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ObexExampleApp());
}

class ObexExampleApp extends StatelessWidget {
  const ObexExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ObexWorkflowPage(),
    );
  }
}

class ObexWorkflowPage extends StatefulWidget {
  const ObexWorkflowPage({super.key});

  @override
  State<ObexWorkflowPage> createState() => _ObexWorkflowPageState();
}

class _ObexWorkflowPageState extends State<ObexWorkflowPage> {
  final destinationController = TextEditingController(
    text: 'AA:BB:CC:DD:EE:FF',
  );
  final log = <String>[];
  Directory? tempDir;
  BlueZObexClient? client;
  BlueZObexSession? session;
  List<BlueZObexMessage> messages = [];
  bool simulated = true;
  bool busy = false;

  @override
  void dispose() {
    destinationController.dispose();
    client?.dispose();
    tempDir?.delete(recursive: true).ignore();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      busy = true;
      log.insert(0, '$label...');
    });
    try {
      await action();
      setState(() => log.insert(0, '$label complete'));
    } catch (error) {
      setState(() => log.insert(0, '$label failed: $error'));
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> _connect() async {
    await client?.dispose();
    tempDir ??= await Directory.systemTemp.createTemp('bluez_obex_example_');
    final connected = simulated
        ? await BlueZObexClient.simulated(outputDirectory: tempDir)
        : await BlueZObexClient.connect();
    final createdSession = await connected.createSession(
      destinationController.text,
      target: 'pbap',
    );

    connected.events.listen((event) {
      if (!mounted) {
        return;
      }
      setState(() => log.insert(0, 'event: ${event.type.name}'));
    });

    setState(() {
      client = connected;
      session = createdSession;
      messages = [];
      log.insert(0, 'session: ${createdSession.objectPath}');
    });
  }

  Future<void> _syncContacts() async {
    final current = session;
    if (current == null) {
      throw StateError('Connect first');
    }
    final file = File('${tempDir!.path}/contacts.vcf');
    await current.phonebook.select('telecom', 'pb');
    final entries = await current.phonebook.list(filters: {'MaxCount': 50});
    final transfer = await current.phonebook.pullAll(file.path);
    setState(() {
      log.insert(0, 'contacts: ${entries.length} entries -> ${file.path}');
      log.insert(0, 'transfer: ${transfer.transferPath}');
    });
  }

  Future<void> _listInbox() async {
    final current = session;
    if (current == null) {
      throw StateError('Connect first');
    }
    final access = current.messageAccess;
    await access.setFolder('inbox');
    final inboxMessages = await access.listMessages('inbox');
    setState(() {
      messages = inboxMessages;
      log.insert(0, 'inbox: ${messages.length} messages');
    });
  }

  Future<void> _downloadMessage(BlueZObexMessage message) async {
    final file = File('${tempDir!.path}/message.bmsg');
    final transfer = await message.get(file.path, attachment: false);
    await message.setRead(true);
    setState(() {
      log.insert(0, 'message: ${file.path}');
      log.insert(0, 'transfer: ${transfer.transferPath}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentSession = session;
    return Scaffold(
      appBar: AppBar(title: const Text('BlueZ OBEX Native')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Simulated endpoint'),
            value: simulated,
            onChanged: busy
                ? null
                : (value) => setState(() => simulated = value),
          ),
          TextField(
            controller: destinationController,
            decoration: const InputDecoration(
              labelText: 'Bluetooth address',
              border: OutlineInputBorder(),
            ),
            enabled: !busy,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: busy ? null : () => _run('connect', _connect),
                child: const Text('Connect'),
              ),
              FilledButton.tonal(
                onPressed: busy || currentSession == null
                    ? null
                    : () => _run('sync contacts', _syncContacts),
                child: const Text('Sync contacts'),
              ),
              FilledButton.tonal(
                onPressed: busy || currentSession == null
                    ? null
                    : () => _run('list inbox', _listInbox),
                child: const Text('List inbox'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (messages.isNotEmpty) ...[
            Text('Inbox', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final message in messages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  message.lastProperties?.subject ?? message.objectPath,
                ),
                subtitle: Text(message.lastProperties?.sender ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: busy
                      ? null
                      : () => _run(
                          'download message',
                          () => _downloadMessage(message),
                        ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('Log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final line in log)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line),
            ),
        ],
      ),
    );
  }
}
