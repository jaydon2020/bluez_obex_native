import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/material.dart';

const _pbapUuid = '0000112f-0000-1000-8000-00805f9b34fb';
const _mapUuid = '00001132-0000-1000-8000-00805f9b34fb';

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
  final _limitController = TextEditingController(text: '10');
  final _log = <String>[];
  Directory? _workspace;
  BlueZObexClient? _client;
  BlueZObexSession? _session;
  StreamSubscription<BlueZObexEvent>? _eventSubscription;
  List<BlueZDevice> _devices = const [];
  String? _selectedAddress;
  List<BlueZObexPhonebookEntry> _contacts = const [];
  List<BlueZObexMessage> _messages = const [];
  static const bool _simulated = false;
  bool _busy = false;
  String? _contactsFile;
  String? _messageFile;

  BlueZDevice? get _selectedDevice {
    final selectedAddress = _selectedAddress;
    if (selectedAddress == null) {
      return null;
    }
    for (final device in _devices) {
      if (device.address == selectedAddress) {
        return device;
      }
    }
    return null;
  }

  bool get _canUsePbap {
    if (_simulated) {
      return true;
    }
    final device = _selectedDevice;
    return device != null &&
        device.connected &&
        device.supportsProfileUuid(_pbapUuid);
  }

  bool get _canUseMap {
    if (_simulated) {
      return true;
    }
    final device = _selectedDevice;
    return device != null &&
        device.connected &&
        device.supportsProfileUuid(_mapUuid);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _limitController.dispose();
    _eventSubscription?.cancel();
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

  Future<BlueZObexClient> _ensureClient() async {
    final existing = _client;
    if (existing != null) {
      return existing;
    }

    _workspace ??= await Directory.systemTemp.createTemp('phone_message_');
    final client = _simulated
        ? await BlueZObexClient.simulated(outputDirectory: _workspace)
        : await BlueZObexClient.connect();
    _eventSubscription = client.events.listen((event) {
      if (mounted && _shouldLogEvent(event)) {
        setState(() => _prependLog('event ${event.type.name}'));
      }
    });
    setState(() {
      _client = client;
    });
    return client;
  }

  Future<BlueZObexSession> _createSession(String target) async {
    final profile = target == 'map' ? 'MAP messages' : 'PBAP contacts';
    final requiredUuid = target == 'map' ? _mapUuid : _pbapUuid;
    final address = _simulated
        ? (_selectedAddress ?? _addressController.text.trim())
        : _selectedDevice?.address;
    if (address == null || address.isEmpty) {
      throw StateError('Choose or enter a Bluetooth address first');
    }
    if (!_simulated) {
      final device = _selectedDevice;
      if (device == null) {
        throw StateError('Choose a discovered BlueZ device first');
      }
      if (!device.connected) {
        throw StateError(
          '${device.name} is not connected. Connect it in system Bluetooth '
          'settings before using $profile.',
        );
      }
      if (!device.supportsProfileUuid(requiredUuid)) {
        throw StateError(
          '${device.name} is connected, but it does not advertise $profile.',
        );
      }
    }
    final client = await _ensureClient();
    final existing = _session;
    if (existing?.lastProperties?.target == target ||
        existing?.lastProperties?.target == requiredUuid) {
      return existing!;
    }

    final BlueZObexSession session;
    try {
      session = await client.createSession(address, target: target);
    } on BlueZObexNativeException catch (error) {
      throw StateError(
        'Could not start $profile for $address. Connect the phone in system '
        'Bluetooth settings and make sure it supports this OBEX profile. '
        'Native error: $error',
      );
    }
    setState(() {
      _session = session;
      _prependLog('$target session ${session.objectPath}');
    });
    return session;
  }

  Future<void> _refreshDevices() async {
    final devices = await BlueZObexClient.devices(simulated: _simulated);
    final connectedDevices = devices.where((device) => device.connected);
    final selectedAddress =
        _selectedAddress != null &&
            devices.any((device) => device.address == _selectedAddress)
        ? _selectedAddress
        : connectedDevices.isNotEmpty
        ? connectedDevices.first.address
        : devices.isNotEmpty
        ? devices.first.address
        : null;
    if (selectedAddress != null) {
      _addressController.text = selectedAddress;
    }
    setState(() {
      _devices = devices;
      _selectedAddress = selectedAddress;
      _prependLog('found ${devices.length} BlueZ device(s)');
    });
  }

  Future<void> _syncContacts() async {
    final session = await _createSession('pbap');
    final phonebook = session.phonebook;
    await phonebook.select('int', 'pb');
    final limit = int.tryParse(_limitController.text) ?? 10;
    final contacts = await phonebook.list(filters: {'MaxCount': limit});
    final targetFile = '${_workspace!.path}/contacts.vcf';
    await _waitForTransferComplete(
      () => phonebook.pullAll(targetFile, filters: {'MaxCount': limit}),
    );
    setState(() {
      _contacts = contacts;
      _contactsFile = targetFile;
      _prependLog('saved contacts.vcf');
    });
  }

  Future<void> _loadInbox() async {
    final session = await _createSession('map');
    final access = session.messageAccess;
    final limit = int.tryParse(_limitController.text) ?? 10;
    final messages = await access.listMessages(
      'telecom/msg/inbox',
      filters: {'MaxCount': limit, 'SubjectLength': 120},
    );
    setState(() {
      _messages = messages;
      _prependLog('loaded ${messages.length} inbox message(s)');
    });
  }

  Future<void> _downloadMessage(BlueZObexMessage message) async {
    final targetFile = '${_workspace!.path}/message.bmsg';
    await _waitForTransferComplete(
      () => message.get(targetFile, attachment: false),
    );
    await message.setRead(true);
    setState(() {
      _messageFile = targetFile;
      _prependLog('saved message.bmsg');
    });
  }

  Future<void> _showContactDetails(BlueZObexPhonebookEntry contact) async {
    final fields = await _loadContactFields(contact);
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ContactDetailSheet(contact: contact, fields: fields),
    );
  }

  Future<List<_ContactField>> _loadContactFields(
    BlueZObexPhonebookEntry contact,
  ) async {
    final fields = [
      _ContactField('Name', contact.name),
      _ContactField('vCard', contact.vcard),
    ];
    final contactsFile = _contactsFile;
    if (contactsFile == null) {
      return fields;
    }

    final file = File(contactsFile);
    if (!await file.exists()) {
      return fields;
    }

    final block = _findVCardBlock(contact, await file.readAsString());
    if (block == null) {
      return fields;
    }

    final parsed = _parseVCardFields(block);
    return [
      for (final field in [...fields, ...parsed])
        if (field.hasContent) field,
    ];
  }

  String? _findVCardBlock(BlueZObexPhonebookEntry contact, String content) {
    final blocks = <List<String>>[];
    var current = <String>[];
    var inCard = false;

    for (final rawLine in content.replaceAll('\r\n', '\n').split('\n')) {
      final line = rawLine.trimRight();
      if (line.toUpperCase() == 'BEGIN:VCARD') {
        inCard = true;
        current = [line];
      } else if (line.toUpperCase() == 'END:VCARD' && inCard) {
        current.add(line);
        blocks.add(_unfoldVCardLines(current));
        inCard = false;
      } else if (inCard) {
        current.add(line);
      }
    }

    bool matches(List<String> lines) {
      for (final line in lines) {
        final separator = line.indexOf(':');
        if (separator < 0) {
          continue;
        }
        final name = line
            .substring(0, separator)
            .split(';')
            .first
            .toUpperCase();
        final value = _decodeVCardValue(line.substring(separator + 1));
        if (name == 'UID' && value == contact.vcard) {
          return true;
        }
        if (name == 'FN' && value == contact.name) {
          return true;
        }
      }
      return lines.join('\n').contains(contact.vcard);
    }

    for (final block in blocks) {
      if (matches(block)) {
        return block.join('\n');
      }
    }
    return blocks.length == 1 ? blocks.single.join('\n') : null;
  }

  List<_ContactField> _parseVCardFields(String block) {
    final fields = <_ContactField>[];
    for (final line in _unfoldVCardLines(block.split('\n'))) {
      final separator = line.indexOf(':');
      if (separator < 0) {
        continue;
      }
      final metadata = line.substring(0, separator);
      final rawName = metadata.split(';').first.toUpperCase();
      if (rawName == 'BEGIN' || rawName == 'END' || rawName == 'VERSION') {
        continue;
      }

      final rawValue = _decodeVCardValue(line.substring(separator + 1));
      final imageBytes = _decodeVCardImage(rawName, rawValue);
      if (imageBytes != null) {
        fields.add(
          _ContactField.image(_vCardLabel(rawName, metadata), imageBytes),
        );
        continue;
      }

      final value = switch (rawName) {
        'ADR' =>
          rawValue.split(';').where((part) => part.isNotEmpty).join(', '),
        'N' => rawValue.split(';').where((part) => part.isNotEmpty).join(' '),
        _ => rawValue,
      };
      fields.add(_ContactField(_vCardLabel(rawName, metadata), value));
    }
    return fields;
  }

  Uint8List? _decodeVCardImage(String name, String value) {
    if (name != 'PHOTO' && name != 'LOGO') {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      return null;
    }
    try {
      return base64Decode(normalized);
    } on FormatException {
      return null;
    }
  }

  List<String> _unfoldVCardLines(List<String> lines) {
    final result = <String>[];
    for (final line in lines) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (result.isNotEmpty) {
          result[result.length - 1] += line.substring(1);
        }
      } else {
        result.add(line);
      }
    }
    return result;
  }

  String _decodeVCardValue(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\;', ';')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\\', r'\');
  }

  String _vCardLabel(String name, String metadata) {
    final base = switch (name) {
      'FN' => 'Full name',
      'N' => 'Structured name',
      'TEL' => 'Phone',
      'EMAIL' => 'Email',
      'ADR' => 'Address',
      'ORG' => 'Organization',
      'TITLE' => 'Title',
      'URL' => 'URL',
      'BDAY' => 'Birthday',
      'NOTE' => 'Note',
      'UID' => 'UID',
      'PHOTO' => 'Photo',
      'LOGO' => 'Logo',
      _ => name,
    };
    final type = _vCardType(metadata);
    return type == null ? base : '$base ($type)';
  }

  String? _vCardType(String metadata) {
    final parts = metadata.split(';').skip(1);
    for (final part in parts) {
      final pieces = part.split('=');
      if (pieces.length == 2 && pieces.first.toUpperCase() == 'TYPE') {
        return pieces.last.toLowerCase();
      }
    }
    return null;
  }

  Future<BlueZObexTransferResult> _waitForTransferComplete(
    Future<BlueZObexTransferResult> Function() startTransfer,
  ) async {
    final client = _requireClient();
    final completedPaths = <String>{};
    final removedPaths = <String>{};
    final failedStatuses = <String, String>{};
    final completer = Completer<void>();
    String? transferPath;

    final subscription = client.events.listen((event) {
      switch (event.type) {
        case BlueZObexEventType.transfer:
          final payload = event.payload;
          if (payload is! BlueZObexTransferProps) {
            return;
          }
          if (payload.status == 'complete') {
            completedPaths.add(payload.objectPath);
            if (payload.objectPath == transferPath && !completer.isCompleted) {
              completer.complete();
            }
          } else if (payload.status == 'error' ||
              payload.status == 'failed' ||
              payload.status == 'cancelled') {
            failedStatuses[payload.objectPath] = payload.status;
            if (payload.objectPath == transferPath && !completer.isCompleted) {
              completer.completeError(
                StateError('Transfer ${payload.objectPath} ${payload.status}'),
              );
            }
          }
        case BlueZObexEventType.objectRemoved:
          final payload = event.payload;
          if (payload is BlueZObexObjectRemoved &&
              payload.interfaceName == 'org.bluez.obex.Transfer1') {
            removedPaths.add(payload.objectPath);
            if (payload.objectPath == transferPath && !completer.isCompleted) {
              completer.complete();
            }
          }
        default:
          return;
      }
    });

    try {
      final result = await startTransfer();
      transferPath = result.transferPath;

      final resultStatus = _transferResultStatus(result);
      if (resultStatus == 'complete') {
        return result;
      }
      if (resultStatus == 'error' ||
          resultStatus == 'failed' ||
          resultStatus == 'cancelled') {
        throw StateError('Transfer ${result.transferPath} $resultStatus');
      }

      final failedStatus = failedStatuses[transferPath];
      if (failedStatus != null) {
        throw StateError('Transfer $transferPath $failedStatus');
      }
      if (completedPaths.contains(transferPath) ||
          removedPaths.contains(transferPath)) {
        return result;
      }
      await completer.future.timeout(const Duration(minutes: 2));
      return result;
    } finally {
      await subscription.cancel();
    }
  }

  String? _transferResultStatus(BlueZObexTransferResult result) {
    for (final property in result.properties) {
      if (property.key == 'Status') {
        return property.value;
      }
    }
    return null;
  }

  BlueZObexClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError('Start a transfer first');
    }
    return client;
  }

  bool _shouldLogEvent(BlueZObexEvent event) {
    return event.type == BlueZObexEventType.session ||
        event.type == BlueZObexEventType.transfer ||
        event.type == BlueZObexEventType.error ||
        event.type == BlueZObexEventType.objectRemoved;
  }

  void _prependLog(String message) {
    _log.insert(0, message);
    if (_log.length > 8) {
      _log.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Message')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionPanel(
            addressController: _addressController,
            busy: _busy,
            devices: _devices,
            selectedAddress: _selectedAddress,
            selectedDevice: _selectedDevice,
            onRefreshDevices: () => _run('refresh devices', _refreshDevices),
            onDeviceSelected: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedAddress = value;
                _addressController.text = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limitController,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Limit (max messages / contacts)',
              helperText: 'Limits the number of contacts and messages to retrieve.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _busy || !_canUsePbap
                    ? null
                    : () => _run('sync contacts', _syncContacts),
                icon: const Icon(Icons.contacts, size: 18),
                label: const Text('Sync contacts'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy || !_canUseMap
                    ? null
                    : () => _run('list inbox', _loadInbox),
                icon: const Icon(Icons.inbox, size: 18),
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
                minLeadingWidth: 28,
                leading: const Icon(Icons.person, size: 18),
                title: Text(contact.name),
                subtitle: Text(contact.vcard),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _showContactDetails(contact),
              ),
          ],
          if (_messages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Inbox', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final message in _messages)
              ListTile(
                contentPadding: EdgeInsets.zero,
                minLeadingWidth: 28,
                leading: const Icon(Icons.message, size: 18),
                title: Text(
                  message.lastProperties?.subject ?? message.objectPath,
                ),
                subtitle: Text(message.lastProperties?.sender ?? ''),
                trailing: IconButton(
                  tooltip: 'Download message',
                  icon: const Icon(Icons.download, size: 18),
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
  final bool busy;
  final List<BlueZDevice> devices;
  final String? selectedAddress;
  final BlueZDevice? selectedDevice;
  final VoidCallback onRefreshDevices;
  final ValueChanged<String?> onDeviceSelected;

  const _ConnectionPanel({
    required this.addressController,
    required this.busy,
    required this.devices,
    required this.selectedAddress,
    required this.selectedDevice,
    required this.onRefreshDevices,
    required this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue:
                    devices.any((device) => device.address == selectedAddress)
                    ? selectedAddress
                    : null,
                items: [
                  for (final device in devices)
                    DropdownMenuItem(
                      value: device.address,
                      child: Text(_deviceLabel(device)),
                    ),
                ],
                onChanged: busy || devices.isEmpty ? null : onDeviceSelected,
                decoration: const InputDecoration(
                  labelText: 'BlueZ device',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh BlueZ devices',
              onPressed: busy ? null : onRefreshDevices,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: addressController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Bluetooth address',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(_deviceStatusText(selectedDevice)),
      ],
    );
  }

  String _deviceStatusText(BlueZDevice? device) {
    if (device == null) {
      return 'Refresh and choose a connected phone';
    }
    if (!device.connected) {
      return '${device.name} is not connected';
    }
    final hasPbap = device.supportsProfileUuid(_pbapUuid);
    final hasMap = device.supportsProfileUuid(_mapUuid);
    if (hasPbap && hasMap) {
      return '${device.name} is connected and supports contacts and inbox';
    }
    if (hasPbap) {
      return '${device.name} is connected and supports contacts only';
    }
    if (hasMap) {
      return '${device.name} is connected and supports inbox only';
    }
    return '${device.name} is connected but does not advertise contacts or inbox';
  }

  String _deviceLabel(BlueZDevice device) {
    final state = device.connected ? 'connected' : 'disconnected';
    final profiles = [
      if (device.supportsProfileUuid(_pbapUuid)) 'contacts',
      if (device.supportsProfileUuid(_mapUuid)) 'inbox',
    ].join('/');
    final suffix = profiles.isEmpty ? state : '$state, $profiles';
    return '${device.name} (${device.address}) - $suffix';
  }
}

class _ContactField {
  final String label;
  final String value;
  final Uint8List? imageBytes;

  const _ContactField(this.label, this.value) : imageBytes = null;

  const _ContactField.image(this.label, this.imageBytes) : value = '';

  bool get hasContent => imageBytes != null || value.trim().isNotEmpty;
}

class _ContactDetailSheet extends StatelessWidget {
  final BlueZObexPhonebookEntry contact;
  final List<_ContactField> fields;

  const _ContactDetailSheet({required this.contact, required this.fields});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                contact.vcard,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: fields.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (field.imageBytes case final imageBytes?)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                imageBytes,
                                width: 88,
                                height: 88,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                isAntiAlias: false,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Text('Could not decode image'),
                              ),
                            )
                          else
                            SelectableText(field.value),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
            Text(session?.objectPath ?? 'No OBEX session yet'),
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
