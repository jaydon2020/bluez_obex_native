import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/material.dart';

const _pbapUuid = '0000112f-0000-1000-8000-00805f9b34fb';
const _mapUuid = '00001132-0000-1000-8000-00805f9b34fb';

void main() => runApp(const FlutterPhoneMessageApp());

class FlutterPhoneMessageApp extends StatelessWidget {
  final bool simulatedByDefault;

  const FlutterPhoneMessageApp({super.key, this.simulatedByDefault = true});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff006a6a);
    return MaterialApp(
      title: 'OBEX Phone Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xfff5f7f6),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: PhoneMessageHome(simulatedByDefault: simulatedByDefault),
    );
  }
}

class PhoneMessageHome extends StatefulWidget {
  final bool simulatedByDefault;

  const PhoneMessageHome({super.key, this.simulatedByDefault = true});

  @override
  State<PhoneMessageHome> createState() => _PhoneMessageHomeState();
}

class _PhoneMessageHomeState extends State<PhoneMessageHome> {
  final _addressController = TextEditingController(text: 'AA:BB:CC:DD:EE:FF');
  final _limitController = TextEditingController(text: '25');
  final _offsetController = TextEditingController(text: '0');
  final _phonebookLocationController = TextEditingController(text: 'int');
  final _phonebookNameController = TextEditingController(text: 'pb');
  final _searchFieldController = TextEditingController(text: 'name');
  final _searchController = TextEditingController(text: 'Ada');
  final _vcardController = TextEditingController(text: '1.vcf');
  final _folderController = TextEditingController(text: 'telecom/msg/inbox');
  final _subjectLengthController = TextEditingController(text: '120');
  final _recipientController = TextEditingController(text: '+10000000000');
  final _messageBodyController = TextEditingController(
    text: 'Hello from bluez_obex_native',
  );

  final _activity = <_ActivityEntry>[];
  final _transfers = <String, BlueZObexTransferProps>{};
  final _transferWatchers = <_TransferWatcher>{};
  final _contactFiles = <String, String>{};
  final _deletedMessages = <String>{};

  Directory? _workspace;
  BlueZObexClient? _client;
  StreamSubscription<BlueZObexEvent>? _eventSubscription;
  BlueZObexSession? _pbapSession;
  BlueZObexSession? _mapSession;
  BlueZObexSessionProps? _pbapSessionProps;
  BlueZObexSessionProps? _mapSessionProps;
  BlueZObexPhonebookProps? _phonebookProps;
  BlueZObexMessageAccessProps? _messageAccessProps;
  BlueZObexManagedObjects? _managedObjects;
  List<BlueZDevice> _devices = const [];
  List<BlueZObexPhonebookEntry> _contacts = const [];
  List<BlueZObexMessageFolder> _folders = const [];
  List<BlueZObexMessage> _messages = const [];
  List<String> _phonebookFilterFields = const [];
  List<String> _messageFilterFields = const [];
  String? _selectedAddress;
  String? _selectedMessagePath;
  String? _contactsFile;
  String? _messageFile;
  String _pbapCapabilities = '';
  String _mapCapabilities = '';
  String? _operation;
  int? _phonebookSize;
  int _pageIndex = 0;
  int _clientEpoch = 0;
  bool _simulated = true;
  bool _busy = false;
  bool _closing = false;
  bool _limitAll = false;
  bool _includeAttachments = true;
  bool _pushTransparent = false;
  bool _pushRetry = true;

  bool get _alive => mounted && !_closing;

  BlueZDevice? get _selectedDevice {
    for (final device in _devices) {
      if (device.address == _selectedAddress) return device;
    }
    return null;
  }

  BlueZObexMessage? get _selectedMessage {
    for (final message in _messages) {
      if (message.objectPath == _selectedMessagePath) return message;
    }
    return null;
  }

  bool get _canUsePbap =>
      _simulated ||
      (_selectedDevice?.connected == true &&
          _selectedDevice!.supportsProfileUuid(_pbapUuid));

  bool get _canUseMap =>
      _simulated ||
      (_selectedDevice?.connected == true &&
          _selectedDevice!.supportsProfileUuid(_mapUuid));

  @override
  void initState() {
    super.initState();
    _simulated = widget.simulatedByDefault;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_alive) unawaited(_run('Discover devices', _refreshDevices));
    });
  }

  @override
  void dispose() {
    _closing = true;
    _clientEpoch++;
    final subscription = _eventSubscription;
    final client = _client;
    final workspace = _workspace;
    final watchers = _transferWatchers.toList();
    final sessions = _sessionsForCleanup();
    _eventSubscription = null;
    _client = null;
    _workspace = null;
    _transferWatchers.clear();
    unawaited(
      _disposeOwnedResources(
        subscription,
        client,
        workspace,
        watchers,
        sessions,
      ),
    );
    for (final controller in [
      _addressController,
      _limitController,
      _offsetController,
      _phonebookLocationController,
      _phonebookNameController,
      _searchFieldController,
      _searchController,
      _vcardController,
      _folderController,
      _subjectLengthController,
      _recipientController,
      _messageBodyController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _disposeOwnedResources(
    StreamSubscription<BlueZObexEvent>? subscription,
    BlueZObexClient? client,
    Directory? workspace,
    List<_TransferWatcher> watchers,
    List<BlueZObexSession> sessions,
  ) async {
    for (final watcher in watchers) {
      try {
        await watcher.abort();
      } catch (_) {}
    }
    try {
      await subscription?.cancel();
    } catch (_) {}
    for (final session in sessions) {
      try {
        await session.remove();
      } catch (_) {}
    }
    try {
      await client?.dispose();
    } catch (_) {}
    try {
      if (workspace != null && await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    } catch (_) {}
  }

  List<BlueZObexSession> _sessionsForCleanup() {
    final sessions = <BlueZObexSession>[];
    for (final session in [_pbapSession, _mapSession]) {
      if (session != null &&
          !sessions.any((value) => value.objectPath == session.objectPath)) {
        sessions.add(session);
      }
    }
    return sessions;
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy || !_alive) return;
    setState(() {
      _busy = true;
      _operation = label;
      _addActivity(label, detail: 'Started');
    });
    try {
      await action();
      if (_alive) setState(() => _addActivity(label, detail: 'Complete'));
    } catch (error) {
      if (!mounted) return;
      if (!_closing) {
        setState(() => _addActivity(label, detail: '$error', error: true));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('$label failed: $error'),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (_alive) {
        setState(() {
          _busy = false;
          _operation = null;
        });
      }
    }
  }

  void _addActivity(String title, {String detail = '', bool error = false}) {
    _activity.insert(0, _ActivityEntry(DateTime.now(), title, detail, error));
    if (_activity.length > 80) _activity.removeRange(80, _activity.length);
  }

  Future<BlueZObexClient> _ensureClient() async {
    final existing = _client;
    if (existing != null) return existing;

    final workspace = Directory.systemTemp.createTempSync(
      'flutter_phone_message_',
    );
    final client = _simulated
        ? await BlueZObexClient.simulated(outputDirectory: workspace)
        : await BlueZObexClient.connect();
    if (!_alive) {
      await client.dispose();
      await workspace.delete(recursive: true);
      throw StateError('The view was closed while connecting');
    }

    final epoch = ++_clientEpoch;
    final subscription = client.events.listen(
      (event) => _handleEvent(event, epoch),
      onError: (Object error, StackTrace stackTrace) {
        if (_alive && epoch == _clientEpoch) {
          setState(
            () => _addActivity(
              'Event stream error',
              detail: '$error',
              error: true,
            ),
          );
        }
      },
      onDone: () {
        if (_alive && epoch == _clientEpoch) {
          setState(() => _addActivity('Event stream', detail: 'Closed'));
        }
      },
    );
    setState(() {
      _workspace = workspace;
      _client = client;
      _eventSubscription = subscription;
      _addActivity(
        'Endpoint connected',
        detail: _simulated ? 'Simulated BlueZ OBEX' : 'System BlueZ OBEX',
      );
    });
    return client;
  }

  Future<void> _disconnect() async {
    final subscription = _eventSubscription;
    final client = _client;
    final workspace = _workspace;
    final watchers = _transferWatchers.toList();
    final sessions = _sessionsForCleanup();
    _clientEpoch++;
    _eventSubscription = null;
    _client = null;
    _workspace = null;
    _transferWatchers.clear();
    if (_alive) setState(_clearEndpointState);
    await _disposeOwnedResources(
      subscription,
      client,
      workspace,
      watchers,
      sessions,
    );
  }

  void _clearEndpointState() {
    _pbapSession = null;
    _mapSession = null;
    _pbapSessionProps = null;
    _mapSessionProps = null;
    _phonebookProps = null;
    _messageAccessProps = null;
    _managedObjects = null;
    _contacts = const [];
    _folders = const [];
    _messages = const [];
    _transfers.clear();
    _contactFiles.clear();
    _deletedMessages.clear();
    _selectedMessagePath = null;
    _contactsFile = null;
    _messageFile = null;
    _phonebookSize = null;
    _phonebookFilterFields = const [];
    _messageFilterFields = const [];
    _pbapCapabilities = '';
    _mapCapabilities = '';
  }

  Future<void> _switchEndpoint(bool simulated) {
    return _run('Switch endpoint', () async {
      await _disconnect();
      if (!_alive) return;
      setState(() {
        _simulated = simulated;
        _devices = const [];
        _selectedAddress = null;
      });
      await _refreshDevices();
    });
  }

  Future<void> _refreshDevices() async {
    final devices = await BlueZObexClient.devices(simulated: _simulated);
    if (!_alive) return;
    final current = _selectedAddress;
    final selected = devices.any((device) => device.address == current)
        ? current
        : devices.where((device) => device.connected).firstOrNull?.address ??
              devices.firstOrNull?.address;
    setState(() {
      _devices = devices;
      _selectedAddress = selected;
      if (selected != null) _addressController.text = selected;
      _addActivity('Devices refreshed', detail: '${devices.length} found');
    });
  }

  Future<void> _selectDevice(String? address) async {
    if (address == null || address == _selectedAddress) return;
    await _run('Change device', () async {
      await _disconnect();
      if (_alive) {
        setState(() {
          _selectedAddress = address;
          _addressController.text = address;
        });
      }
    });
  }

  String _destinationFor(String profile, String uuid) {
    final address = _simulated
        ? (_selectedAddress ?? _addressController.text.trim())
        : _selectedDevice?.address;
    if (address == null || address.isEmpty) {
      throw StateError('Choose a Bluetooth device first');
    }
    if (!_simulated) {
      final device = _selectedDevice;
      if (device == null || !device.connected) {
        throw StateError('The selected device is not connected');
      }
      if (!device.supportsProfileUuid(uuid)) {
        throw StateError('${device.name} does not advertise $profile');
      }
    }
    return address;
  }

  Future<BlueZObexSession> _ensurePbapSession() async {
    final existing = _pbapSession;
    if (existing != null) return existing;
    final client = await _ensureClient();
    final session = await client.createSession(
      _destinationFor('PBAP', _pbapUuid),
      target: 'pbap',
    );
    final props = await session.properties();
    final capabilities = await session.capabilities();
    if (!_alive) {
      await session.remove();
      throw StateError('The view was closed while creating PBAP');
    }
    setState(() {
      _pbapSession = session;
      _pbapSessionProps = props;
      _pbapCapabilities = capabilities;
    });
    return session;
  }

  Future<BlueZObexSession> _ensureMapSession() async {
    final existing = _mapSession;
    if (existing != null) return existing;
    final client = await _ensureClient();
    final session = await client.createSession(
      _destinationFor('MAP', _mapUuid),
      target: 'map',
    );
    final props = await session.properties();
    final capabilities = await session.capabilities();
    if (!_alive) {
      await session.remove();
      throw StateError('The view was closed while creating MAP');
    }
    setState(() {
      _mapSession = session;
      _mapSessionProps = props;
      _mapCapabilities = capabilities;
    });
    return session;
  }

  Future<void> _openPbap() async {
    final session = await _ensurePbapSession();
    final results = await Future.wait<Object>([
      session.phonebook.properties(),
      session.phonebook.getSize(),
      session.phonebook.listFilterFields(),
    ]);
    if (_alive) {
      setState(() {
        _phonebookProps = results[0] as BlueZObexPhonebookProps;
        _phonebookSize = results[1] as int;
        _phonebookFilterFields = results[2] as List<String>;
      });
    }
  }

  Future<void> _closePbap() async {
    final session = _pbapSession;
    if (session == null) return;
    await session.remove();
    if (_alive) {
      setState(() {
        _pbapSession = null;
        _pbapSessionProps = null;
        _phonebookProps = null;
        _contacts = const [];
        _phonebookSize = null;
        _phonebookFilterFields = const [];
      });
    }
  }

  Map<String, Object?> _listFilters({bool messages = false}) {
    final filters = <String, Object?>{};
    if (!_limitAll) {
      final maxCount = int.tryParse(_limitController.text.trim());
      if (maxCount == null || maxCount < 0 || maxCount > 65535) {
        throw const FormatException('MaxCount must be between 0 and 65535');
      }
      filters['MaxCount'] = maxCount;
    }
    final offset = int.tryParse(_offsetController.text.trim());
    if (offset == null || offset < 0 || offset > 65535) {
      throw const FormatException('Offset must be between 0 and 65535');
    }
    filters['Offset'] = offset;
    if (messages) {
      final length = int.tryParse(_subjectLengthController.text.trim());
      if (length == null || length < 0 || length > 255) {
        throw const FormatException('SubjectLength must be between 0 and 255');
      }
      filters['SubjectLength'] = length;
    }
    return filters;
  }

  Future<void> _selectPhonebook() async {
    final phonebook = (await _ensurePbapSession()).phonebook;
    await phonebook.select(
      _phonebookLocationController.text.trim(),
      _phonebookNameController.text.trim(),
    );
    final props = await phonebook.properties();
    if (_alive) setState(() => _phonebookProps = props);
  }

  Future<void> _listContacts() async {
    final phonebook = (await _ensurePbapSession()).phonebook;
    final contacts = await phonebook.list(filters: _listFilters());
    if (_alive) setState(() => _contacts = contacts);
  }

  Future<void> _searchContacts() async {
    final phonebook = (await _ensurePbapSession()).phonebook;
    final contacts = await phonebook.search(
      _searchFieldController.text.trim(),
      _searchController.text.trim(),
      filters: _listFilters(),
    );
    if (_alive) setState(() => _contacts = contacts);
  }

  Future<void> _pullAllContacts() async {
    final session = await _ensurePbapSession();
    final target = '${_workspace!.path}/contacts.vcf';
    await _waitForTransfer(
      () => session.phonebook.pullAll(target, filters: _listFilters()),
    );
    if (_alive) setState(() => _contactsFile = target);
  }

  Future<void> _pullContact() async {
    final session = await _ensurePbapSession();
    final vcard = _vcardController.text.trim();
    if (vcard.isEmpty) throw const FormatException('Enter a vCard handle');
    final safeName = vcard
        .split('/')
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = '${_workspace!.path}/$safeName';
    await _waitForTransfer(
      () => session.phonebook.pull(vcard, target, filters: _listFilters()),
    );
    if (_alive) setState(() => _contactFiles[vcard] = target);
  }

  Future<void> _getPhonebookSize() async {
    final size = await (await _ensurePbapSession()).phonebook.getSize();
    if (_alive) setState(() => _phonebookSize = size);
  }

  Future<void> _updatePhonebookVersion() async {
    final phonebook = (await _ensurePbapSession()).phonebook;
    await phonebook.updateVersion();
    final props = await phonebook.properties();
    if (_alive) setState(() => _phonebookProps = props);
  }

  Future<void> _loadPhonebookFilterFields() async {
    final fields = await (await _ensurePbapSession()).phonebook
        .listFilterFields();
    if (_alive) setState(() => _phonebookFilterFields = fields);
  }

  Future<void> _openMap() async {
    final session = await _ensureMapSession();
    final results = await Future.wait<Object>([
      session.messageAccess.properties(),
      session.messageAccess.listFilterFields(),
    ]);
    if (_alive) {
      setState(() {
        _messageAccessProps = results[0] as BlueZObexMessageAccessProps;
        _messageFilterFields = results[1] as List<String>;
      });
    }
  }

  Future<void> _closeMap() async {
    final session = _mapSession;
    if (session == null) return;
    await session.remove();
    if (_alive) {
      setState(() {
        _mapSession = null;
        _mapSessionProps = null;
        _messageAccessProps = null;
        _folders = const [];
        _messages = const [];
        _selectedMessagePath = null;
        _messageFilterFields = const [];
      });
    }
  }

  Future<void> _setMessageFolder() async {
    await (await _ensureMapSession()).messageAccess.setFolder(
      _folderController.text.trim(),
    );
  }

  Future<void> _listFolders() async {
    final folders = await (await _ensureMapSession()).messageAccess.listFolders(
      filters: _listFilters(),
    );
    if (_alive) setState(() => _folders = folders);
  }

  Future<void> _listMessages() async {
    final session = await _ensureMapSession();
    final messages = await session.messageAccess.listMessages(
      _folderController.text.trim(),
      filters: _listFilters(messages: true),
    );
    if (_alive) {
      setState(() {
        _messages = messages;
        _selectedMessagePath = messages.firstOrNull?.objectPath;
      });
    }
  }

  Future<void> _loadMessageFilterFields() async {
    final fields = await (await _ensureMapSession()).messageAccess
        .listFilterFields();
    if (_alive) setState(() => _messageFilterFields = fields);
  }

  Future<void> _updateInbox() async {
    await (await _ensureMapSession()).messageAccess.updateInbox();
  }

  Future<void> _pushMessage() async {
    final session = await _ensureMapSession();
    final recipient = _recipientController.text.trim();
    final source = File('${_workspace!.path}/outgoing.bmsg');
    source.writeAsStringSync(
      'BEGIN:BMSG\r\nVERSION:1.0\r\nSTATUS:UNREAD\r\nTYPE:SMS_GSM\r\n'
      'BEGIN:BENV\r\nBEGIN:VCARD\r\nVERSION:2.1\r\nTEL:$recipient\r\n'
      'END:VCARD\r\nBEGIN:BBODY\r\nBEGIN:MSG\r\n'
      '${_messageBodyController.text}\r\nEND:MSG\r\nEND:BBODY\r\n'
      'END:BENV\r\nEND:BMSG\r\n',
    );
    await _waitForTransfer(
      () => session.messageAccess.pushMessage(
        source.path,
        _folderController.text.trim(),
        args: {
          'Recipient': recipient,
          'Transparent': _pushTransparent,
          'Retry': _pushRetry,
        },
      ),
    );
  }

  Future<void> _refreshMessage(BlueZObexMessage message) async {
    final props = await message.properties();
    if (_alive) setState(() => _replaceMessage(props));
  }

  Future<void> _downloadMessage(BlueZObexMessage message) async {
    final target =
        '${_workspace!.path}/${message.objectPath.split('/').last}.bmsg';
    await _waitForTransfer(
      () => message.get(target, attachment: _includeAttachments),
    );
    if (_alive) setState(() => _messageFile = target);
  }

  Future<void> _setMessageRead(BlueZObexMessage message, bool read) async {
    await message.setRead(read);
    await _refreshMessage(message);
  }

  Future<void> _setMessageDeleted(
    BlueZObexMessage message,
    bool deleted,
  ) async {
    await message.setDeleted(deleted);
    if (_alive) {
      setState(() {
        if (deleted) {
          _deletedMessages.add(message.objectPath);
        } else {
          _deletedMessages.remove(message.objectPath);
        }
      });
    }
  }

  void _replaceMessage(BlueZObexMessageProps props) {
    final client = _client;
    if (client == null) return;
    final replacement = client.message(props.objectPath, props);
    final index = _messages.indexWhere(
      (message) => message.objectPath == props.objectPath,
    );
    if (index < 0) {
      _messages = [..._messages, replacement];
    } else {
      final updated = [..._messages];
      updated[index] = replacement;
      _messages = updated;
    }
  }

  Future<BlueZObexTransferResult> _waitForTransfer(
    Future<BlueZObexTransferResult> Function() start,
  ) async {
    final client = await _ensureClient();
    final watcher = _TransferWatcher();
    String? transferPath;
    final completed = <String>{};
    final removed = <String>{};
    final failures = <String, String>{};

    watcher.subscription = client.events.listen(
      (event) {
        final payload = event.payload;
        if (event.type == BlueZObexEventType.transfer &&
            payload is BlueZObexTransferProps) {
          final props = payload;
          if (props.status == 'complete') {
            completed.add(props.objectPath);
            if (props.objectPath == transferPath) watcher.complete();
          } else if (_isFailedStatus(props.status)) {
            failures[props.objectPath] = props.status;
            if (props.objectPath == transferPath) {
              watcher.fail(StateError('Transfer ${props.status}'));
            }
          }
        } else if (event.type == BlueZObexEventType.objectRemoved &&
            payload is BlueZObexObjectRemoved &&
            payload.interfaceName == 'org.bluez.obex.Transfer1') {
          final object = payload;
          removed.add(object.objectPath);
          if (object.objectPath == transferPath) watcher.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) => watcher.fail(error),
      onDone: () => watcher.fail(StateError('Event stream closed')),
    );
    _transferWatchers.add(watcher);

    try {
      final result = await start();
      transferPath = result.transferPath;
      _rememberTransferResult(result);
      final status = _resultProperty(result, 'Status');
      if (status == 'complete') return result;
      if (_isFailedStatus(status)) throw StateError('Transfer $status');
      if (failures[transferPath] case final failed?) {
        throw StateError('Transfer $failed');
      }
      if (completed.contains(transferPath) || removed.contains(transferPath)) {
        return result;
      }
      await watcher.completer.future.timeout(const Duration(minutes: 2));
      if (watcher.error case final error?) throw error;
      return result;
    } finally {
      _transferWatchers.remove(watcher);
      await watcher.close();
    }
  }

  bool _isFailedStatus(String? status) =>
      status == 'error' || status == 'failed' || status == 'cancelled';

  String? _resultProperty(BlueZObexTransferResult result, String key) {
    for (final property in result.properties) {
      if (property.key == key) return property.value;
    }
    return null;
  }

  void _rememberTransferResult(BlueZObexTransferResult result) {
    if (!context.mounted || _closing) return;
    final existing = _transfers[result.transferPath];
    setState(() {
      _transfers[result.transferPath] = BlueZObexTransferProps(
        objectPath: result.transferPath,
        status: _resultProperty(result, 'Status') ?? existing?.status ?? '',
        session: existing?.session ?? '',
        name: existing?.name ?? '',
        type: existing?.type ?? '',
        time: existing?.time ?? 0,
        size: existing?.size ?? 0,
        transferred: existing?.transferred ?? 0,
        filename:
            _resultProperty(result, 'Filename') ?? existing?.filename ?? '',
      );
    });
  }

  Future<void> _transferAction(
    String path,
    Future<void> Function(BlueZObexTransfer transfer) action,
  ) async {
    final client = await _ensureClient();
    final transfer = client.transfer(path, _transfers[path]);
    await action(transfer);
    final props = await transfer.properties();
    if (_alive) setState(() => _transfers[path] = props);
  }

  Future<void> _refreshManagedObjects() async {
    final objects = await (await _ensureClient()).getManagedObjects();
    if (_alive) setState(() => _managedObjects = objects);
  }

  void _handleEvent(BlueZObexEvent event, int epoch) {
    if (!_alive || epoch != _clientEpoch) return;
    setState(() {
      final payload = event.payload;
      switch (payload) {
        case BlueZObexSessionProps props:
          if (props.target == 'pbap' || props.target == _pbapUuid) {
            _pbapSessionProps = props;
          } else if (props.target == 'map' || props.target == _mapUuid) {
            _mapSessionProps = props;
          }
        case BlueZObexPhonebookProps props:
          _phonebookProps = props;
        case BlueZObexMessageAccessProps props:
          _messageAccessProps = props;
        case BlueZObexMessageProps props:
          _replaceMessage(props);
        case BlueZObexTransferProps props:
          _transfers[props.objectPath] = props;
        case BlueZObexObjectRemoved object:
          if (object.interfaceName == 'org.bluez.obex.Transfer1') {
            _transfers.remove(object.objectPath);
          } else if (object.interfaceName == 'org.bluez.obex.Message1') {
            _messages = _messages
                .where((message) => message.objectPath != object.objectPath)
                .toList();
          } else if (object.interfaceName == 'org.bluez.obex.Session1') {
            if (_pbapSession?.objectPath == object.objectPath) {
              _pbapSession = null;
              _pbapSessionProps = null;
            }
            if (_mapSession?.objectPath == object.objectPath) {
              _mapSession = null;
              _mapSessionProps = null;
            }
          } else if (object.interfaceName ==
                  'org.bluez.obex.PhonebookAccess1' &&
              _phonebookProps?.objectPath == object.objectPath) {
            _phonebookProps = null;
          } else if (object.interfaceName == 'org.bluez.obex.MessageAccess1' &&
              _messageAccessProps?.objectPath == object.objectPath) {
            _messageAccessProps = null;
          }
        case BlueZObexError error:
          _addActivity(error.name, detail: error.message, error: true);
        default:
          break;
      }
      _addActivity(
        'Event · ${event.type.name}',
        detail: _eventSummary(payload),
        error: event.type == BlueZObexEventType.error,
      );
    });
  }

  String _eventSummary(Object? payload) => switch (payload) {
    BlueZObexSessionProps value => value.objectPath,
    BlueZObexPhonebookProps value => value.folder,
    BlueZObexMessageAccessProps value => value.supportedTypes.join(', '),
    BlueZObexMessageProps value => value.subject,
    BlueZObexTransferProps value => '${value.status} ${value.objectPath}',
    BlueZObexObjectAdded value => '${value.interfaceName} ${value.objectPath}',
    BlueZObexObjectRemoved value =>
      '${value.interfaceName} ${value.objectPath}',
    BlueZObexError value => '${value.name}: ${value.message}',
    _ => payload?.toString() ?? '',
  };

  Future<void> _showContact(BlueZObexPhonebookEntry contact) async {
    final fields = await _loadContactFields(contact);
    if (!mounted) return;
    if (_closing) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ContactDetailSheet(contact: contact, fields: fields),
    );
  }

  Future<List<_ContactField>> _loadContactFields(
    BlueZObexPhonebookEntry contact,
  ) async {
    final fields = [
      _ContactField('Name', contact.name),
      _ContactField('vCard handle', contact.vcard),
    ];
    final path = _contactFiles[contact.vcard] ?? _contactsFile;
    if (path == null) return fields;
    final file = File(path);
    if (!await file.exists()) return fields;
    final block = _findVCardBlock(contact, await file.readAsString());
    return block == null
        ? fields
        : [
            ...fields,
            ..._parseVCardFields(block),
          ].where((field) => field.hasContent).toList();
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
      final joined = lines.join('\n');
      return joined.contains(contact.vcard) || joined.contains(contact.name);
    }

    return blocks.where(matches).firstOrNull?.join('\n') ??
        (blocks.length == 1 ? blocks.single.join('\n') : null);
  }

  List<_ContactField> _parseVCardFields(String block) {
    final fields = <_ContactField>[];
    for (final line in _unfoldVCardLines(block.split('\n'))) {
      final separator = line.indexOf(':');
      if (separator < 0) continue;
      final metadata = line.substring(0, separator);
      final name = metadata.split(';').first.toUpperCase();
      if (name == 'BEGIN' || name == 'END' || name == 'VERSION') continue;
      final rawValue = _decodeVCardValue(line.substring(separator + 1));
      final image = _decodeVCardImage(name, rawValue);
      if (image != null) {
        fields.add(_ContactField.image(_vCardLabel(name, metadata), image));
      } else {
        final value = (name == 'ADR' || name == 'N')
            ? rawValue
                  .split(';')
                  .where((part) => part.isNotEmpty)
                  .join(name == 'ADR' ? ', ' : ' ')
            : rawValue;
        fields.add(_ContactField(_vCardLabel(name, metadata), value));
      }
    }
    return fields;
  }

  List<String> _unfoldVCardLines(List<String> lines) {
    final result = <String>[];
    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          result.isNotEmpty) {
        result[result.length - 1] += line.substring(1);
      } else {
        result.add(line);
      }
    }
    return result;
  }

  String _decodeVCardValue(String value) => value
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\\', r'\');

  Uint8List? _decodeVCardImage(String name, String value) {
    if (name != 'PHOTO' && name != 'LOGO') return null;
    try {
      return base64Decode(value.replaceAll(RegExp(r'\s+'), ''));
    } on FormatException {
      return null;
    }
  }

  String _vCardLabel(String name, String metadata) {
    final label = switch (name) {
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
    final type = RegExp(
      r'(?:^|;)TYPE=([^;:]+)',
      caseSensitive: false,
    ).firstMatch(metadata)?.group(1);
    return type == null ? label : '$label (${type.toLowerCase()})';
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      _Destination('Overview', Icons.dashboard_outlined, Icons.dashboard),
      _Destination('Contacts', Icons.contacts_outlined, Icons.contacts),
      _Destination('Messages', Icons.chat_outlined, Icons.chat),
      _Destination('Transfers', Icons.sync_alt_outlined, Icons.sync_alt),
      _Destination('Activity', Icons.receipt_long_outlined, Icons.receipt_long),
    ];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OBEX Phone Studio'),
            Text(
              'PBAP + MAP control surface',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: Icon(
                _simulated ? Icons.science_outlined : Icons.bluetooth,
                size: 18,
              ),
              label: Text(_simulated ? 'Simulated endpoint' : 'System BlueZ'),
            ),
          ),
        ],
        bottom: _busy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Column(
                  children: [
                    const LinearProgressIndicator(minHeight: 2),
                    SizedBox(
                      height: 26,
                      child: Center(
                        child: Text(
                          _operation ?? 'Working…',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final page = _buildPage();
          if (!wide) {
            return Column(
              children: [
                Expanded(child: page),
                NavigationBar(
                  selectedIndex: _pageIndex,
                  onDestinationSelected: (index) {
                    setState(() => _pageIndex = index);
                  },
                  destinations: [
                    for (final destination in destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _pageIndex,
                onDestinationSelected: (index) {
                  setState(() => _pageIndex = index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPage() => switch (_pageIndex) {
    1 => _contactsPage(),
    2 => _messagesPage(),
    3 => _transfersPage(),
    4 => _activityPage(),
    _ => _overviewPage(),
  };

  Widget _pageList(List<Widget> children) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
    children: children,
  );

  Widget _overviewPage() => _pageList([
    const _PageHeader(
      eyebrow: 'BLUEZ OBEX',
      title: 'Phone data, without hidden state',
      description:
          'Connect once, inspect every interface, and watch PBAP/MAP events as they happen.',
    ),
    const SizedBox(height: 16),
    _responsiveCards([_connectionCard(), _statusCard()]),
    const SizedBox(height: 16),
    _responsiveCards([
      _sessionCard('PBAP session', _pbapSessionProps, _pbapCapabilities),
      _sessionCard('MAP session', _mapSessionProps, _mapCapabilities),
    ]),
  ]);

  Widget _connectionCard() => _SectionCard(
    title: 'Endpoint',
    subtitle: 'Choose simulation or a connected BlueZ phone.',
    icon: Icons.bluetooth_searching,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              icon: Icon(Icons.science_outlined),
              label: Text('Simulated'),
            ),
            ButtonSegment(
              value: false,
              icon: Icon(Icons.bluetooth),
              label: Text('System BlueZ'),
            ),
          ],
          selected: {_simulated},
          onSelectionChanged: _busy
              ? null
              : (selection) => unawaited(_switchEndpoint(selection.single)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  '${_simulated}_${_devices.length}_$_selectedAddress',
                ),
                initialValue:
                    _devices.any((device) => device.address == _selectedAddress)
                    ? _selectedAddress
                    : null,
                decoration: const InputDecoration(labelText: 'BlueZ device'),
                isExpanded: true,
                items: [
                  for (final device in _devices)
                    DropdownMenuItem(
                      value: device.address,
                      child: Text(
                        '${device.name} · ${device.address}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (value) => unawaited(_selectDevice(value)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Refresh devices',
              onPressed: _busy
                  ? null
                  : () => _run('Discover devices', _refreshDevices),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          enabled: _simulated && !_busy,
          decoration: const InputDecoration(labelText: 'Bluetooth address'),
        ),
        const SizedBox(height: 12),
        _DeviceSupport(device: _selectedDevice, simulated: _simulated),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run('Connect endpoint', _ensureClient),
              icon: const Icon(Icons.power),
              label: Text(_client == null ? 'Connect' : 'Connected'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _client == null
                  ? null
                  : () => _run('Disconnect endpoint', _disconnect),
              icon: const Icon(Icons.power_off),
              label: const Text('Disconnect'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _statusCard() {
    final objects = _managedObjects;
    return _SectionCard(
      title: 'Object manager',
      subtitle: 'Live objects currently exported by org.bluez.obex.',
      icon: Icons.account_tree_outlined,
      actions: [
        IconButton(
          tooltip: 'Refresh managed objects',
          onPressed: _busy
              ? null
              : () => _run('Refresh objects', _refreshManagedObjects),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          _MetricRow('Sessions', objects?.sessions.length ?? 0),
          _MetricRow('Phonebooks', objects?.phonebooks.length ?? 0),
          _MetricRow('Message access', objects?.messageAccesses.length ?? 0),
          _MetricRow('Messages', objects?.messages.length ?? _messages.length),
          _MetricRow(
            'Transfers',
            objects?.transfers.length ?? _transfers.length,
          ),
          const Divider(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _workspace?.path ?? 'Temporary workspace is created on connect.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(
    String title,
    BlueZObexSessionProps? props,
    String capabilities,
  ) => _SectionCard(
    title: title,
    subtitle: props == null ? 'Not connected' : props.objectPath,
    icon: Icons.link,
    child: _MetadataTable(
      rows: [
        ('Source', props?.source ?? '—'),
        ('Destination', props?.destination ?? '—'),
        ('Channel', '${props?.channel ?? 0}'),
        ('PSM', props == null ? '—' : '0x${props.psm.toRadixString(16)}'),
        ('Target', props?.target ?? '—'),
        ('Root', props?.root ?? '—'),
        ('Capabilities', capabilities.isEmpty ? '—' : capabilities),
      ],
    ),
  );

  Widget _contactsPage() => _pageList([
    const _PageHeader(
      eyebrow: 'PBAP',
      title: 'Contacts and phonebooks',
      description:
          'Select, inspect, list, search, and pull complete or individual vCards.',
    ),
    const SizedBox(height: 16),
    _profileActions(
      enabled: _canUsePbap,
      connected: _pbapSession != null,
      openLabel: 'Open PBAP',
      onOpen: () => _run('Open PBAP', _openPbap),
      onClose: () => _run('Close PBAP', _closePbap),
      actions: [
        _Action('Select', Icons.folder_open, _selectPhonebook),
        _Action('List', Icons.list, _listContacts),
        _Action('Search', Icons.search, _searchContacts),
        _Action('Pull all', Icons.download, _pullAllContacts),
        _Action('Pull one', Icons.person_search, _pullContact),
        _Action('Get size', Icons.numbers, _getPhonebookSize),
        _Action('Update version', Icons.update, _updatePhonebookVersion),
        _Action('Filter fields', Icons.filter_alt, _loadPhonebookFilterFields),
      ],
    ),
    const SizedBox(height: 16),
    _responsiveCards([_pbapParameters(), _phonebookMetadata()]),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Contact results',
      subtitle:
          '${_contacts.length} entries${_contactsFile == null ? '' : ' · $_contactsFile'}',
      icon: Icons.contacts_outlined,
      child: _contacts.isEmpty
          ? const _EmptyState(
              icon: Icons.person_search,
              message: 'List or search the selected phonebook.',
            )
          : Column(
              children: [
                for (final contact in _contacts)
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        contact.name.trim().isEmpty
                            ? '?'
                            : contact.name.trim()[0].toUpperCase(),
                      ),
                    ),
                    title: Text(contact.name),
                    subtitle: Text(contact.vcard),
                    trailing: IconButton(
                      tooltip: 'Pull this vCard',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: _busy
                          ? null
                          : () {
                              _vcardController.text = contact.vcard;
                              _run('Pull ${contact.name}', _pullContact);
                            },
                    ),
                    onTap: () => _showContact(contact),
                  ),
              ],
            ),
    ),
  ]);

  Widget _pbapParameters() => _SectionCard(
    title: 'PBAP request',
    subtitle: 'Selection, pagination, and search parameters.',
    icon: Icons.tune,
    child: Column(
      children: [
        _fieldPair(
          TextField(
            controller: _phonebookLocationController,
            decoration: const InputDecoration(labelText: 'Location'),
          ),
          TextField(
            controller: _phonebookNameController,
            decoration: const InputDecoration(labelText: 'Phonebook'),
          ),
        ),
        const SizedBox(height: 12),
        _fieldPair(
          TextField(
            controller: _searchFieldController,
            decoration: const InputDecoration(labelText: 'Search field'),
          ),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(labelText: 'Search value'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vcardController,
          decoration: const InputDecoration(labelText: 'vCard handle'),
        ),
        const SizedBox(height: 12),
        _paginationFields(),
      ],
    ),
  );

  Widget _phonebookMetadata() {
    final props = _phonebookProps;
    return _SectionCard(
      title: 'Phonebook metadata',
      subtitle: _phonebookSize == null
          ? 'No size loaded'
          : '$_phonebookSize entries',
      icon: Icons.badge_outlined,
      child: _MetadataTable(
        rows: [
          ('Object', props?.objectPath ?? '—'),
          ('Folder', props?.folder ?? '—'),
          ('Database ID', props?.databaseIdentifier ?? '—'),
          ('Primary counter', props?.primaryCounter ?? '—'),
          ('Secondary counter', props?.secondaryCounter ?? '—'),
          ('Fixed image size', '${props?.fixedImageSize ?? false}'),
          (
            'Filter fields',
            _phonebookFilterFields.isEmpty
                ? '—'
                : _phonebookFilterFields.join(', '),
          ),
        ],
      ),
    );
  }

  Widget _messagesPage() => _pageList([
    const _PageHeader(
      eyebrow: 'MAP',
      title: 'Folders and messages',
      description:
          'Browse folders, synchronize the inbox, inspect every message field, download, push, and change flags.',
    ),
    const SizedBox(height: 16),
    _profileActions(
      enabled: _canUseMap,
      connected: _mapSession != null,
      openLabel: 'Open MAP',
      onOpen: () => _run('Open MAP', _openMap),
      onClose: () => _run('Close MAP', _closeMap),
      actions: [
        _Action('Set folder', Icons.drive_file_move, _setMessageFolder),
        _Action('List folders', Icons.folder_copy_outlined, _listFolders),
        _Action(
          'List messages',
          Icons.mark_email_unread_outlined,
          _listMessages,
        ),
        _Action('Update inbox', Icons.sync, _updateInbox),
        _Action('Push message', Icons.send_outlined, _pushMessage),
        _Action('Filter fields', Icons.filter_alt, _loadMessageFilterFields),
      ],
    ),
    const SizedBox(height: 16),
    _responsiveCards([_mapParameters(), _messageAccessMetadata()]),
    const SizedBox(height: 16),
    if (_folders.isNotEmpty)
      _SectionCard(
        title: 'Folders',
        subtitle: '${_folders.length} returned',
        icon: Icons.folder_outlined,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final folder in _folders)
              ActionChip(
                avatar: const Icon(Icons.folder, size: 18),
                label: Text(folder.name),
                onPressed: () {
                  _folderController.text = folder.name.startsWith('telecom/')
                      ? folder.name
                      : 'telecom/msg/${folder.name}';
                },
              ),
          ],
        ),
      ),
    if (_folders.isNotEmpty) const SizedBox(height: 16),
    LayoutBuilder(
      builder: (context, constraints) {
        final list = _messageList();
        final details = _messageDetails(_selectedMessage);
        if (constraints.maxWidth < 1000) {
          return Column(children: [list, const SizedBox(height: 16), details]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: list),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: details),
          ],
        );
      },
    ),
  ]);

  Widget _mapParameters() => _SectionCard(
    title: 'MAP request',
    subtitle: 'Folder, pagination, download, and push options.',
    icon: Icons.tune,
    child: Column(
      children: [
        TextField(
          controller: _folderController,
          decoration: const InputDecoration(labelText: 'Folder'),
        ),
        const SizedBox(height: 12),
        _paginationFields(messages: true),
        const SizedBox(height: 12),
        TextField(
          controller: _recipientController,
          decoration: const InputDecoration(labelText: 'Push recipient'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageBodyController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Push message body'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Transparent push'),
          value: _pushTransparent,
          onChanged: _busy
              ? null
              : (value) => setState(() => _pushTransparent = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Retry push'),
          value: _pushRetry,
          onChanged: _busy
              ? null
              : (value) => setState(() => _pushRetry = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Download attachments'),
          value: _includeAttachments,
          onChanged: _busy
              ? null
              : (value) => setState(() => _includeAttachments = value),
        ),
      ],
    ),
  );

  Widget _messageAccessMetadata() {
    final props = _messageAccessProps;
    return _SectionCard(
      title: 'Message access metadata',
      subtitle: props?.objectPath ?? 'Open MAP to inspect capabilities.',
      icon: Icons.sms_outlined,
      child: _MetadataTable(
        rows: [
          ('Object', props?.objectPath ?? '—'),
          (
            'Supported types',
            props == null || props.supportedTypes.isEmpty
                ? '—'
                : props.supportedTypes.join(', '),
          ),
          (
            'Filter fields',
            _messageFilterFields.isEmpty
                ? '—'
                : _messageFilterFields.join(', '),
          ),
          ('Last download', _messageFile ?? '—'),
        ],
      ),
    );
  }

  Widget _messageList() => _SectionCard(
    title: 'Messages',
    subtitle: '${_messages.length} returned',
    icon: Icons.inbox_outlined,
    child: _messages.isEmpty
        ? const _EmptyState(
            icon: Icons.mark_email_unread_outlined,
            message: 'List messages from a MAP folder.',
          )
        : Column(
            children: [
              for (final message in _messages)
                ListTile(
                  selected: message.objectPath == _selectedMessagePath,
                  leading: Icon(
                    message.lastProperties?.read == true
                        ? Icons.drafts_outlined
                        : Icons.mark_email_unread,
                  ),
                  title: Text(
                    message.lastProperties?.subject.isNotEmpty == true
                        ? message.lastProperties!.subject
                        : message.objectPath.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    message.lastProperties?.sender ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: message.lastProperties?.priority == true
                      ? const Icon(Icons.priority_high)
                      : null,
                  onTap: () {
                    setState(() => _selectedMessagePath = message.objectPath);
                  },
                ),
            ],
          ),
  );

  Widget _messageDetails(BlueZObexMessage? message) {
    final props = message?.lastProperties;
    if (message == null || props == null) {
      return const _SectionCard(
        title: 'Message metadata',
        subtitle: 'Select a message',
        icon: Icons.info_outline,
        child: _EmptyState(
          icon: Icons.touch_app_outlined,
          message: 'Choose a message to inspect every Message1 property.',
        ),
      );
    }
    final requestedDeleted = _deletedMessages.contains(message.objectPath);
    return _SectionCard(
      title: props.subject.isEmpty ? 'Message metadata' : props.subject,
      subtitle: message.objectPath,
      icon: Icons.info_outline,
      actions: [
        IconButton(
          tooltip: 'Refresh Message1 properties',
          onPressed: _busy
              ? null
              : () => _run('Refresh message', () => _refreshMessage(message)),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'Download message',
                        () => _downloadMessage(message),
                      ),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        props.read ? 'Mark unread' : 'Mark read',
                        () => _setMessageRead(message, !props.read),
                      ),
                icon: Icon(props.read ? Icons.mark_email_unread : Icons.drafts),
                label: Text(props.read ? 'Mark unread' : 'Mark read'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        requestedDeleted ? 'Restore message' : 'Delete message',
                        () => _setMessageDeleted(message, !requestedDeleted),
                      ),
                icon: Icon(
                  requestedDeleted
                      ? Icons.restore_from_trash
                      : Icons.delete_outline,
                ),
                label: Text(requestedDeleted ? 'Restore' : 'Delete'),
              ),
            ],
          ),
          const Divider(height: 24),
          _MetadataTable(rows: _messageRows(props, requestedDeleted)),
        ],
      ),
    );
  }

  List<(String, String)> _messageRows(
    BlueZObexMessageProps props,
    bool requestedDeleted,
  ) => [
    ('Folder', props.folder),
    ('Subject', props.subject),
    ('Timestamp', props.timestamp),
    ('Sender', props.sender),
    ('Sender address', props.senderAddress),
    ('Reply-to', props.replyTo),
    ('Recipient', props.recipient),
    ('Recipient address', props.recipientAddress),
    ('Type', props.type),
    ('Size', '${props.size} bytes'),
    ('Text', '${props.text}'),
    ('Status', props.status),
    ('Attachment size', '${props.attachmentSize} bytes'),
    ('Priority', '${props.priority}'),
    ('Read', '${props.read}'),
    ('Deleted', '${props.deleted}'),
    ('Deleted request', '$requestedDeleted'),
    ('Sent', '${props.sent}'),
    ('Protected', '${props.protected}'),
    ('Delivery status', props.deliveryStatus),
    ('Conversation ID', '${props.conversationId}'),
    ('Conversation name', props.conversationName),
    ('Direction', props.direction),
    ('Attachment MIME types', props.attachmentMimeTypes),
  ];

  Widget _transfersPage() => _pageList([
    const _PageHeader(
      eyebrow: 'TRANSFER1',
      title: 'Transfer lifecycle',
      description:
          'Inspect progress and call Cancel, Suspend, or Resume on any tracked transfer.',
    ),
    const SizedBox(height: 16),
    if (_transfers.isEmpty)
      const _SectionCard(
        title: 'Transfers',
        subtitle: 'No transfers yet',
        icon: Icons.sync_alt,
        child: _EmptyState(
          icon: Icons.cloud_sync_outlined,
          message: 'Pull a contact, download a message, or push a message.',
        ),
      )
    else
      for (final transfer in _transfers.values) ...[
        _transferCard(transfer),
        const SizedBox(height: 12),
      ],
  ]);

  Widget _transferCard(BlueZObexTransferProps transfer) {
    final progress = transfer.size > 0
        ? (transfer.transferred / transfer.size).clamp(0.0, 1.0)
        : null;
    return _SectionCard(
      title: transfer.name.isEmpty
          ? transfer.objectPath.split('/').last
          : transfer.name,
      subtitle:
          '${transfer.status} · ${transfer.type.isEmpty ? 'unknown type' : transfer.type}',
      icon: Icons.swap_vert_circle_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'Refresh transfer',
                        () =>
                            _transferAction(transfer.objectPath, (_) async {}),
                      ),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'Suspend transfer',
                        () => _transferAction(
                          transfer.objectPath,
                          (value) => value.suspend(),
                        ),
                      ),
                icon: const Icon(Icons.pause),
                label: const Text('Suspend'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'Resume transfer',
                        () => _transferAction(
                          transfer.objectPath,
                          (value) => value.resume(),
                        ),
                      ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run(
                        'Cancel transfer',
                        () => _transferAction(
                          transfer.objectPath,
                          (value) => value.cancel(),
                        ),
                      ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            ],
          ),
          const Divider(height: 24),
          _MetadataTable(
            rows: [
              ('Object', transfer.objectPath),
              ('Status', transfer.status),
              ('Session', transfer.session),
              ('Name', transfer.name),
              ('Type', transfer.type),
              ('Time', '${transfer.time}'),
              ('Size', '${transfer.size} bytes'),
              ('Transferred', '${transfer.transferred} bytes'),
              ('Filename', transfer.filename),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityPage() => _pageList([
    const _PageHeader(
      eyebrow: 'OBJECT MANAGER',
      title: 'Live event journal',
      description:
          'Session, phonebook, message-access, message, transfer, addition, removal, and error events.',
    ),
    const SizedBox(height: 16),
    _SectionCard(
      title: 'Activity',
      subtitle: '${_activity.length} retained events',
      icon: Icons.receipt_long_outlined,
      actions: [
        IconButton(
          tooltip: 'Clear activity',
          onPressed: _activity.isEmpty ? null : () => setState(_activity.clear),
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
      child: _activity.isEmpty
          ? const _EmptyState(
              icon: Icons.notifications_none,
              message: 'Events will appear here after connecting.',
            )
          : Column(
              children: [
                for (final entry in _activity)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      entry.error ? Icons.error_outline : Icons.bolt,
                      color: entry.error
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(entry.title),
                    subtitle: entry.detail.isEmpty ? null : Text(entry.detail),
                    trailing: Text(_timeLabel(entry.time)),
                  ),
              ],
            ),
    ),
  ]);

  Widget _profileActions({
    required bool enabled,
    required bool connected,
    required String openLabel,
    required VoidCallback onOpen,
    required VoidCallback onClose,
    required List<_Action> actions,
  }) => _SectionCard(
    title: 'Operations',
    subtitle: enabled
        ? 'Every BlueZ profile method is available below.'
        : 'The selected device does not advertise this profile.',
    icon: Icons.terminal,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: _busy || !enabled ? null : onOpen,
          icon: const Icon(Icons.link),
          label: Text(openLabel),
        ),
        OutlinedButton.icon(
          onPressed: _busy || !connected ? null : onClose,
          icon: const Icon(Icons.link_off),
          label: const Text('Close session'),
        ),
        for (final action in actions)
          FilledButton.tonalIcon(
            onPressed: _busy || !enabled
                ? null
                : () => _run(action.label, action.callback),
            icon: Icon(action.icon),
            label: Text(action.label),
          ),
      ],
    ),
  );

  Widget _paginationFields({bool messages = false}) => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Retrieve all'),
        subtitle: const Text('Omit MaxCount'),
        value: _limitAll,
        onChanged: _busy ? null : (value) => setState(() => _limitAll = value),
      ),
      _fieldPair(
        TextField(
          controller: _limitController,
          enabled: !_limitAll,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'MaxCount'),
        ),
        TextField(
          controller: _offsetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Offset'),
        ),
      ),
      if (messages) ...[
        const SizedBox(height: 12),
        TextField(
          controller: _subjectLengthController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'SubjectLength'),
        ),
      ],
    ],
  );

  Widget _fieldPair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 440) {
        return Column(children: [first, const SizedBox(height: 12), second]);
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _responsiveCards(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              cards[index],
              if (index < cards.length - 1) const SizedBox(height: 16),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 16),
          ],
        ],
      );
    },
  );

  String _timeLabel(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}:'
      '${time.second.toString().padLeft(2, '0')}';
}

class _TransferWatcher {
  final completer = Completer<void>();
  late final StreamSubscription<BlueZObexEvent> subscription;
  Object? error;
  bool _closed = false;

  void complete() {
    if (!completer.isCompleted) completer.complete();
  }

  void fail(Object error) {
    this.error = error;
    complete();
  }

  Future<void> abort() async {
    fail(StateError('Transfer listener closed'));
    await close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await subscription.cancel();
  }
}

class _Destination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _Destination(this.label, this.icon, this.selectedIcon);
}

class _Action {
  final String label;
  final IconData icon;
  final Future<void> Function() callback;

  const _Action(this.label, this.icon, this.callback);
}

class _ActivityEntry {
  final DateTime time;
  final String title;
  final String detail;
  final bool error;

  const _ActivityEntry(this.time, this.title, this.detail, this.error);
}

class _PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String description;

  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Icon(
                      icon,
                      size: 20,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetadataTable extends StatelessWidget {
  final List<(String, String)> rows;

  const _MetadataTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    rows[index].$1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    rows[index].$2.isEmpty ? '—' : rows[index].$2,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          if (index < rows.length - 1) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final int value;

  const _MetricRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Badge(label: Text('$value')),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _DeviceSupport extends StatelessWidget {
  final BlueZDevice? device;
  final bool simulated;

  const _DeviceSupport({required this.device, required this.simulated});

  @override
  Widget build(BuildContext context) {
    final selected = device;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _SupportChip(
          label: selected?.connected == true || simulated
              ? 'Connected'
              : 'Disconnected',
          supported: selected?.connected == true || simulated,
        ),
        _SupportChip(
          label: 'PBAP',
          supported:
              simulated || selected?.supportsProfileUuid(_pbapUuid) == true,
        ),
        _SupportChip(
          label: 'MAP',
          supported:
              simulated || selected?.supportsProfileUuid(_mapUuid) == true,
        ),
      ],
    );
  }
}

class _SupportChip extends StatelessWidget {
  final String label;
  final bool supported;

  const _SupportChip({required this.label, required this.supported});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      supported ? Icons.check_circle : Icons.cancel,
      size: 18,
      color: supported
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.error,
    ),
    label: Text(label),
  );
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.name, style: theme.textTheme.headlineSmall),
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
                          const SizedBox(height: 4),
                          if (field.imageBytes case final bytes?)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                bytes,
                                width: 112,
                                height: 112,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
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
