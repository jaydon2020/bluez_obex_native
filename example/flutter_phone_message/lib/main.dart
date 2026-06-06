import 'dart:io';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FlutterPhoneMessageApp());
}

class FlutterPhoneMessageApp extends StatelessWidget {
  const FlutterPhoneMessageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phone Message',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff28666e)),
        useMaterial3: true,
      ),
      home: const PhoneMessageHome(),
    );
  }
}

class PhoneMessageHome extends StatefulWidget {
  const PhoneMessageHome({super.key});

  @override
  State<PhoneMessageHome> createState() => _PhoneMessageHomeState();
}

class _PhoneMessageHomeState extends State<PhoneMessageHome> {
  final _addressController = TextEditingController(text: 'AA:BB:CC:DD:EE:FF');
  final _log = <String>[];
  Directory? _workspace;
  BlueZObexClient? _client;
  BlueZObexSession? _session;
  List<BlueZObexPhonebookEntry> _contacts = const [];
  List<BlueZObexMessage> _messages = const [];
  bool _simulated = true;
  bool _busy = false;
  String? _contactsFile;
  String? _messageFile;

  @override
  void dispose() {
    _addressController.dispose();
    _client?.dispose();
    _workspace?.delete(recursive: true).ignore();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _prependLog('$label...');
    });
    try {
      await action();
      if (mounted) {
        setState(() => _prependLog('$label complete'));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _prependLog('$label failed: $error'));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _connect() async {
    await _client?.dispose();
    _workspace ??= await Directory.systemTemp.createTemp('phone_message_');
    final client = _simulated
        ? await BlueZObexClient.simulated(outputDirectory: _workspace)
        : await BlueZObexClient.connect();
    final session = await client.createSession(
      _addressController.text.trim(),
      target: 'pbap',
    );
    client.events.listen((event) {
      if (mounted) {
        setState(() => _prependLog('event ${event.type.name}'));
      }
    });

    setState(() {
      _client = client;
      _session = session;
      _contacts = const [];
      _messages = const [];
      _contactsFile = null;
      _messageFile = null;
      _prependLog('session ${session.objectPath}');
    });
  }

  Future<void> _syncContacts() async {
    final session = _requireSession();
    final phonebook = session.phonebook;
    await phonebook.select('int', 'pb');
    final contacts = await phonebook.list(filters: {'MaxCount': 50});
    final targetFile = '${_workspace!.path}/contacts.vcf';
    await phonebook.pullAll(targetFile);
    setState(() {
      _contacts = contacts;
      _contactsFile = targetFile;
      _prependLog('saved contacts.vcf');
    });
  }

  Future<void> _loadInbox() async {
    final access = _requireSession().messageAccess;
    await access.setFolder('inbox');
    final messages = await access.listMessages('inbox');
    setState(() {
      _messages = messages;
      _prependLog('loaded ${messages.length} inbox message(s)');
    });
  }

  Future<void> _downloadMessage(BlueZObexMessage message) async {
    final targetFile = '${_workspace!.path}/message.bmsg';
    await message.get(targetFile, attachment: false);
    await message.setRead(true);
    setState(() {
      _messageFile = targetFile;
      _prependLog('saved message.bmsg');
    });
  }

  BlueZObexSession _requireSession() {
    final session = _session;
    if (session == null) {
      throw StateError('Connect to a phone first');
    }
    return session;
  }

  void _prependLog(String message) {
    _log.insert(0, message);
    if (_log.length > 8) {
      _log.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionReady = _session != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Message'),
        actions: [
          IconButton(
            tooltip: 'Connect',
            onPressed: _busy ? null : () => _run('connect', _connect),
            icon: const Icon(Icons.bluetooth_connected),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionPanel(
            addressController: _addressController,
            simulated: _simulated,
            busy: _busy,
            onSimulatedChanged: (value) => setState(() => _simulated = value),
            onConnect: () => _run('connect', _connect),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy || !sessionReady
                    ? null
                    : () => _run('sync contacts', _syncContacts),
                icon: const Icon(Icons.contacts),
                label: const Text('Sync contacts'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy || !sessionReady
                    ? null
                    : () => _run('list inbox', _loadInbox),
                icon: const Icon(Icons.inbox),
                label: const Text('List inbox'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SummaryPanel(
            session: _session,
            contactsCount: _contacts.length,
            messagesCount: _messages.length,
            contactsFile: _contactsFile,
            messageFile: _messageFile,
          ),
          const SizedBox(height: 16),
          if (_contacts.isNotEmpty) ...[
            Text('Contacts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final contact in _contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person),
                title: Text(contact.name),
                subtitle: Text(contact.vcard),
              ),
          ],
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Inbox', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final message in _messages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.message),
                title: Text(
                  message.lastProperties?.subject ?? message.objectPath,
                ),
                subtitle: Text(message.lastProperties?.sender ?? ''),
                trailing: IconButton(
                  tooltip: 'Download message',
                  icon: const Icon(Icons.download),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          'download message',
                          () => _downloadMessage(message),
                        ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text('Activity', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in _log)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(item),
            ),
        ],
      ),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  final TextEditingController addressController;
  final bool simulated;
  final bool busy;
  final ValueChanged<bool> onSimulatedChanged;
  final VoidCallback onConnect;

  const _ConnectionPanel({
    required this.addressController,
    required this.simulated,
    required this.busy,
    required this.onSimulatedChanged,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Simulated endpoint'),
          subtitle: const Text('Disable to use a physical BlueZ OBEX phone'),
          value: simulated,
          onChanged: busy ? null : onSimulatedChanged,
        ),
        TextField(
          controller: addressController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Bluetooth address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: busy ? null : onConnect,
          icon: const Icon(Icons.bluetooth_searching),
          label: const Text('Connect'),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final BlueZObexSession? session;
  final int contactsCount;
  final int messagesCount;
  final String? contactsFile;
  final String? messageFile;

  const _SummaryPanel({
    required this.session,
    required this.contactsCount,
    required this.messagesCount,
    required this.contactsFile,
    required this.messageFile,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(session?.objectPath ?? 'Not connected'),
            const Divider(),
            Text('Contacts synced: $contactsCount'),
            Text('Messages listed: $messagesCount'),
            if (contactsFile != null) Text('vCard: $contactsFile'),
            if (messageFile != null) Text('Message: $messageFile'),
          ],
        ),
      ),
    );
  }
}
