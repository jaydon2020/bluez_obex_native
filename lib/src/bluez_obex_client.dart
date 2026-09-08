import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'ffi/types.dart';
import 'native_bridge.dart';

part 'internal/native_worker.dart';

/// Backend contract used by the public OBEX client classes.
///
/// The default implementation talks to the native FFI library. Tests and the
/// example app can use the simulated backend to exercise the same API without a
/// physical phone or a running `org.bluez.obex` service.
abstract class BlueZObexBackend {
  Stream<BlueZObexEvent> get events;

  Future<List<BlueZDevice>> getDevices();
  Future<BlueZObexManagedObjects> getManagedObjects();
  Future<BlueZObexSessionProps> createSession(
    String destination, {
    String target = 'pbap',
  });
  Future<void> removeSession(String sessionPath);
  Future<BlueZObexSessionProps> sessionProperties(String sessionPath);
  Future<String> sessionCapabilities(String sessionPath);

  Future<BlueZObexTransferProps> transferProperties(String transferPath);
  Future<void> transferCancel(String transferPath);
  Future<void> transferSuspend(String transferPath);
  Future<void> transferResume(String transferPath);

  Future<BlueZObexPhonebookProps> phonebookProperties(String phonebookPath);
  Future<void> phonebookSelect(
    String phonebookPath,
    String location,
    String phonebook,
  );
  Future<BlueZObexTransferResult> phonebookPullAll(
    String phonebookPath,
    String targetFile, {
    Map<String, Object?> filters = const {},
  });
  Future<BlueZObexTransferResult> phonebookPull(
    String phonebookPath,
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  });
  Future<List<BlueZObexPhonebookEntry>> phonebookList(
    String phonebookPath, {
    Map<String, Object?> filters = const {},
  });
  Future<List<BlueZObexPhonebookEntry>> phonebookSearch(
    String phonebookPath,
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  });
  Future<int> phonebookGetSize(String phonebookPath);
  Future<void> phonebookUpdateVersion(String phonebookPath);
  Future<List<String>> phonebookListFilterFields(String phonebookPath);

  Future<BlueZObexMessageAccessProps> messageAccessProperties(
    String messageAccessPath,
  );
  Future<void> messageAccessSetFolder(String messageAccessPath, String folder);
  Future<List<BlueZObexMessageFolder>> messageAccessListFolders(
    String messageAccessPath, {
    Map<String, Object?> filters = const {},
  });
  Future<List<String>> messageAccessListFilterFields(String messageAccessPath);
  Future<List<BlueZObexMessageProps>> messageAccessListMessages(
    String messageAccessPath,
    String folder, {
    Map<String, Object?> filters = const {},
  });
  Future<void> messageAccessUpdateInbox(String messageAccessPath);
  Future<BlueZObexTransferResult> messageAccessPushMessage(
    String messageAccessPath,
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  });

  Future<BlueZObexMessageProps> messageProperties(String messagePath);
  Future<BlueZObexTransferResult> messageGet(
    String messagePath,
    String targetFile, {
    bool attachment = true,
  });
  Future<void> messageSetRead(String messagePath, bool read);
  Future<void> messageSetDeleted(String messagePath, bool deleted);

  Future<void> dispose();
}

/// Entry point for BlueZ OBEX operations.
class BlueZObexClient {
  final BlueZObexBackend _backend;

  BlueZObexClient._(this._backend);

  /// Connect to the real BlueZ OBEX service through the native FFI library.
  static Future<BlueZObexClient> connect() async {
    return BlueZObexClient._(await NativeBlueZObexBackend.connect());
  }

  /// Create an in-process simulated OBEX endpoint for examples and tests.
  static Future<BlueZObexClient> simulated({Directory? outputDirectory}) async {
    return BlueZObexClient._(
      SimulatedBlueZObexBackend(outputDirectory: outputDirectory),
    );
  }

  /// Query BlueZ System Bus devices without creating an OBEX session.
  static Future<List<BlueZDevice>> devices({bool simulated = false}) async {
    if (simulated) {
      return SimulatedBlueZObexBackend.simulatedDevices;
    }
    return NativeBlueZObexBackend.queryDevices();
  }

  /// ObjectManager and property-change events emitted by the backend.
  Stream<BlueZObexEvent> get events => _backend.events;

  Future<List<BlueZDevice>> getDevices() {
    return _backend.getDevices();
  }

  Future<BlueZObexManagedObjects> getManagedObjects() {
    return _backend.getManagedObjects();
  }

  Future<BlueZObexSession> createSession(
    String destination, {
    String target = 'pbap',
  }) async {
    if (target.isEmpty) {
      throw ArgumentError.value(target, 'target', 'Must not be empty');
    }
    final props = await _backend.createSession(destination, target: target);
    return BlueZObexSession._(this, props.objectPath, props);
  }

  BlueZObexSession session(String objectPath) {
    return BlueZObexSession._(this, objectPath, null);
  }

  BlueZObexPhonebook phonebook(String objectPath) {
    return BlueZObexPhonebook._(this, objectPath);
  }

  BlueZObexTransfer transfer(
    String objectPath, [
    BlueZObexTransferProps? props,
  ]) {
    return BlueZObexTransfer._(this, objectPath, props);
  }

  BlueZObexMessageAccess messageAccess(String objectPath) {
    return BlueZObexMessageAccess._(this, objectPath);
  }

  BlueZObexMessage message(String objectPath, [BlueZObexMessageProps? props]) {
    return BlueZObexMessage._(this, objectPath, props);
  }

  Future<void> dispose() {
    return _backend.dispose();
  }
}

/// An OBEX transfer that can be monitored and controlled.
class BlueZObexTransfer {
  final BlueZObexClient _client;
  final String objectPath;
  BlueZObexTransferProps? _lastProps;

  BlueZObexTransfer._(this._client, this.objectPath, this._lastProps);

  BlueZObexTransferProps? get lastProperties => _lastProps;

  Future<BlueZObexTransferProps> properties() async {
    final props = await _client._backend.transferProperties(objectPath);
    _lastProps = props;
    return props;
  }

  Future<void> cancel() => _client._backend.transferCancel(objectPath);

  Future<void> suspend() => _client._backend.transferSuspend(objectPath);

  Future<void> resume() => _client._backend.transferResume(objectPath);
}

/// A connected OBEX session.
class BlueZObexSession {
  final BlueZObexClient _client;
  final String objectPath;
  BlueZObexSessionProps? _lastProps;

  BlueZObexSession._(this._client, this.objectPath, this._lastProps);

  BlueZObexSessionProps? get lastProperties => _lastProps;

  BlueZObexPhonebook get phonebook => _client.phonebook(objectPath);

  BlueZObexMessageAccess get messageAccess => _client.messageAccess(objectPath);

  Future<BlueZObexSessionProps> properties() async {
    final props = await _client._backend.sessionProperties(objectPath);
    _lastProps = props;
    return props;
  }

  Future<String> capabilities() {
    return _client._backend.sessionCapabilities(objectPath);
  }

  Future<void> remove() {
    return _client._backend.removeSession(objectPath);
  }
}

/// Phonebook Access Profile operations for a session object.
class BlueZObexPhonebook {
  final BlueZObexClient _client;
  final String objectPath;

  BlueZObexPhonebook._(this._client, this.objectPath);

  Future<BlueZObexPhonebookProps> properties() {
    return _client._backend.phonebookProperties(objectPath);
  }

  Future<void> select(String location, String phonebook) {
    return _client._backend.phonebookSelect(objectPath, location, phonebook);
  }

  Future<BlueZObexTransferResult> pullAll(
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) {
    return _client._backend.phonebookPullAll(
      objectPath,
      targetFile,
      filters: filters,
    );
  }

  Future<BlueZObexTransferResult> pull(
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) {
    return _client._backend.phonebookPull(
      objectPath,
      vcard,
      targetFile,
      filters: filters,
    );
  }

  Future<List<BlueZObexPhonebookEntry>> list({
    Map<String, Object?> filters = const {},
  }) {
    return _client._backend.phonebookList(objectPath, filters: filters);
  }

  Future<List<BlueZObexPhonebookEntry>> search(
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) {
    return _client._backend.phonebookSearch(
      objectPath,
      field,
      value,
      filters: filters,
    );
  }

  Future<int> getSize() {
    return _client._backend.phonebookGetSize(objectPath);
  }

  Future<void> updateVersion() {
    return _client._backend.phonebookUpdateVersion(objectPath);
  }

  Future<List<String>> listFilterFields() {
    return _client._backend.phonebookListFilterFields(objectPath);
  }
}

/// Message Access Profile operations for a session object.
class BlueZObexMessageAccess {
  final BlueZObexClient _client;
  final String objectPath;

  BlueZObexMessageAccess._(this._client, this.objectPath);

  Future<BlueZObexMessageAccessProps> properties() {
    return _client._backend.messageAccessProperties(objectPath);
  }

  Future<void> setFolder(String folder) {
    return _client._backend.messageAccessSetFolder(objectPath, folder);
  }

  Future<List<BlueZObexMessageFolder>> listFolders({
    Map<String, Object?> filters = const {},
  }) {
    return _client._backend.messageAccessListFolders(
      objectPath,
      filters: filters,
    );
  }

  Future<List<String>> listFilterFields() {
    return _client._backend.messageAccessListFilterFields(objectPath);
  }

  Future<List<BlueZObexMessage>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  }) async {
    final messages = await _client._backend.messageAccessListMessages(
      objectPath,
      folder,
      filters: filters,
    );
    return [
      for (final props in messages)
        BlueZObexMessage._(_client, props.objectPath, props),
    ];
  }

  Future<void> updateInbox() {
    return _client._backend.messageAccessUpdateInbox(objectPath);
  }

  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) {
    return _client._backend.messageAccessPushMessage(
      objectPath,
      sourceFile,
      folder,
      args: args,
    );
  }
}

/// A MAP message object.
class BlueZObexMessage {
  final BlueZObexClient _client;
  final String objectPath;
  BlueZObexMessageProps? _lastProps;

  BlueZObexMessage._(this._client, this.objectPath, this._lastProps);

  BlueZObexMessageProps? get lastProperties => _lastProps;

  Future<BlueZObexMessageProps> properties() async {
    final props = await _client._backend.messageProperties(objectPath);
    _lastProps = props;
    return props;
  }

  Future<BlueZObexTransferResult> get(
    String targetFile, {
    bool attachment = true,
  }) {
    return _client._backend.messageGet(
      objectPath,
      targetFile,
      attachment: attachment,
    );
  }

  Future<void> setRead(bool read) {
    return _client._backend.messageSetRead(objectPath, read);
  }

  Future<void> setDeleted(bool deleted) {
    return _client._backend.messageSetDeleted(objectPath, deleted);
  }
}

class _LocalNativeBlueZObexBackend implements BlueZObexBackend {
  final BlueZObexNativeBridge _bridge;
  final ReceivePort _receivePort;
  final StreamSubscription<dynamic> _receiveSubscription;
  final StreamController<BlueZObexEvent> _eventsController;
  bool _disposed = false;

  _LocalNativeBlueZObexBackend._(
    this._bridge,
    this._receivePort,
    this._receiveSubscription,
    this._eventsController,
  );

  static Future<_LocalNativeBlueZObexBackend> connect() async {
    initializeDartDl();
    final receivePort = ReceivePort();
    final eventsController = StreamController<BlueZObexEvent>.broadcast();
    final receiveSubscription = receivePort.listen((dynamic data) {
      try {
        if (data is Uint8List) {
          final event = decodeNativeEvent(data);
          eventsController.add(event);
          if (event.type == BlueZObexEventType.streamDone) {
            receivePort.close();
            unawaited(eventsController.close());
          }
        } else if (data is List<int>) {
          eventsController.add(decodeNativeEvent(Uint8List.fromList(data)));
        }
      } catch (error, stackTrace) {
        eventsController.addError(error, stackTrace);
      }
    });

    final handle = nativeBindings.bluez_obex_client_create(
      receivePort.sendPort.nativePort,
    );
    if (handle == ffi.nullptr) {
      final error = nativeException('bluez_obex_client_create', -3);
      receivePort.close();
      await receiveSubscription.cancel();
      await eventsController.close();
      throw error;
    }

    return _LocalNativeBlueZObexBackend._(
      BlueZObexNativeBridge(handle),
      receivePort,
      receiveSubscription,
      eventsController,
    );
  }

  @override
  Stream<BlueZObexEvent> get events => _eventsController.stream;

  static Future<List<BlueZDevice>> queryDevices() async {
    final result = readNativeGlaze<BlueZDevices>(
      'bluez_obex_get_devices',
      nativeBindings.bluez_obex_get_devices,
    );
    return result.devices;
  }

  @override
  Future<List<BlueZDevice>> getDevices() async {
    return _LocalNativeBlueZObexBackend.queryDevices();
  }

  @override
  Future<BlueZObexManagedObjects> getManagedObjects() async {
    return _bridge.readGlaze<BlueZObexManagedObjects>(
      'bluez_obex_get_managed_objects',
      (out) =>
          nativeBindings.bluez_obex_get_managed_objects(_bridge.handle, out),
    );
  }

  @override
  Future<BlueZObexSessionProps> createSession(
    String destination, {
    String target = 'pbap',
  }) async {
    if (target.isEmpty) {
      throw ArgumentError.value(target, 'target', 'Must not be empty');
    }
    final destinationPtr = NativeString(destination);
    final targetPtr = NativeString(target);
    try {
      return _bridge.readGlaze<BlueZObexSessionProps>(
        'bluez_obex_client_create_session',
        (out) => nativeBindings.bluez_obex_client_create_session(
          _bridge.handle,
          destinationPtr.pointer,
          targetPtr.pointer,
          out,
        ),
      );
    } finally {
      targetPtr.dispose();
      destinationPtr.dispose();
    }
  }

  @override
  Future<void> removeSession(String sessionPath) async {
    final path = NativeString(sessionPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_client_remove_session',
        nativeBindings.bluez_obex_client_remove_session(
          _bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<BlueZObexSessionProps> sessionProperties(String sessionPath) async {
    final path = NativeString(sessionPath);
    try {
      return _bridge.readGlaze<BlueZObexSessionProps>(
        'bluez_obex_session_get_properties',
        (out) => nativeBindings.bluez_obex_session_get_properties(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<String> sessionCapabilities(String sessionPath) async {
    final path = NativeString(sessionPath);
    try {
      return _bridge.readUtf8(
        'bluez_obex_session_get_capabilities',
        (out) => nativeBindings.bluez_obex_session_get_capabilities(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<BlueZObexTransferProps> transferProperties(String transferPath) async {
    final path = NativeString(transferPath);
    try {
      return _bridge.readGlaze<BlueZObexTransferProps>(
        'bluez_obex_transfer_get_properties',
        (out) => nativeBindings.bluez_obex_transfer_get_properties(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> transferCancel(String transferPath) async {
    final path = NativeString(transferPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_transfer_cancel',
        nativeBindings.bluez_obex_transfer_cancel(_bridge.handle, path.pointer),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> transferSuspend(String transferPath) async {
    final path = NativeString(transferPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_transfer_suspend',
        nativeBindings.bluez_obex_transfer_suspend(
          _bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> transferResume(String transferPath) async {
    final path = NativeString(transferPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_transfer_resume',
        nativeBindings.bluez_obex_transfer_resume(_bridge.handle, path.pointer),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<BlueZObexPhonebookProps> phonebookProperties(
    String phonebookPath,
  ) async {
    final path = NativeString(phonebookPath);
    try {
      return _bridge.readGlaze<BlueZObexPhonebookProps>(
        'bluez_obex_phonebook_get_properties',
        (out) => nativeBindings.bluez_obex_phonebook_get_properties(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> phonebookSelect(
    String phonebookPath,
    String location,
    String phonebook,
  ) async {
    final path = NativeString(phonebookPath);
    final locationPtr = NativeString(location);
    final phonebookPtr = NativeString(phonebook);
    try {
      _bridge.checkStatus(
        'bluez_obex_phonebook_select',
        nativeBindings.bluez_obex_phonebook_select(
          _bridge.handle,
          path.pointer,
          locationPtr.pointer,
          phonebookPtr.pointer,
        ),
      );
    } finally {
      phonebookPtr.dispose();
      locationPtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<BlueZObexTransferResult> phonebookPullAll(
    String phonebookPath,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(phonebookPath);
    final target = NativeString(targetFile);
    final nativeFilters = NativeStringMap(filters);
    try {
      return _bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_phonebook_pull_all',
        (out) => nativeBindings.bluez_obex_phonebook_pull_all(
          _bridge.handle,
          path.pointer,
          target.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
    } finally {
      nativeFilters.dispose();
      target.dispose();
      path.dispose();
    }
  }

  @override
  Future<BlueZObexTransferResult> phonebookPull(
    String phonebookPath,
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(phonebookPath);
    final vcardPtr = NativeString(vcard);
    final target = NativeString(targetFile);
    final nativeFilters = NativeStringMap(filters);
    try {
      return _bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_phonebook_pull',
        (out) => nativeBindings.bluez_obex_phonebook_pull(
          _bridge.handle,
          path.pointer,
          vcardPtr.pointer,
          target.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
    } finally {
      nativeFilters.dispose();
      target.dispose();
      vcardPtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookList(
    String phonebookPath, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(phonebookPath);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _bridge.readGlaze<BlueZObexPhonebookEntries>(
        'bluez_obex_phonebook_list',
        (out) => nativeBindings.bluez_obex_phonebook_list(
          _bridge.handle,
          path.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
      return result.entries;
    } finally {
      nativeFilters.dispose();
      path.dispose();
    }
  }

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookSearch(
    String phonebookPath,
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(phonebookPath);
    final fieldPtr = NativeString(field);
    final valuePtr = NativeString(value);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _bridge.readGlaze<BlueZObexPhonebookEntries>(
        'bluez_obex_phonebook_search',
        (out) => nativeBindings.bluez_obex_phonebook_search(
          _bridge.handle,
          path.pointer,
          fieldPtr.pointer,
          valuePtr.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
      return result.entries;
    } finally {
      nativeFilters.dispose();
      valuePtr.dispose();
      fieldPtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<int> phonebookGetSize(String phonebookPath) async {
    final path = NativeString(phonebookPath);
    try {
      final size = nativeBindings.bluez_obex_phonebook_get_size(
        _bridge.handle,
        path.pointer,
      );
      _bridge.checkStatus('bluez_obex_phonebook_get_size', size);
      return size;
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> phonebookUpdateVersion(String phonebookPath) async {
    final path = NativeString(phonebookPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_phonebook_update_version',
        nativeBindings.bluez_obex_phonebook_update_version(
          _bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<List<String>> phonebookListFilterFields(String phonebookPath) async {
    final path = NativeString(phonebookPath);
    try {
      final result = _bridge.readGlaze<BlueZObexFilterFields>(
        'bluez_obex_phonebook_list_filter_fields',
        (out) => nativeBindings.bluez_obex_phonebook_list_filter_fields(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
      return result.fields;
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> messageAccessSetFolder(
    String messageAccessPath,
    String folder,
  ) async {
    final path = NativeString(messageAccessPath);
    final folderPtr = NativeString(folder);
    try {
      _bridge.checkStatus(
        'bluez_obex_message_access_set_folder',
        nativeBindings.bluez_obex_message_access_set_folder(
          _bridge.handle,
          path.pointer,
          folderPtr.pointer,
        ),
      );
    } finally {
      folderPtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<BlueZObexMessageAccessProps> messageAccessProperties(
    String messageAccessPath,
  ) async {
    final path = NativeString(messageAccessPath);
    try {
      return _bridge.readGlaze<BlueZObexMessageAccessProps>(
        'bluez_obex_message_access_get_properties',
        (out) => nativeBindings.bluez_obex_message_access_get_properties(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<List<BlueZObexMessageFolder>> messageAccessListFolders(
    String messageAccessPath, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(messageAccessPath);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _bridge.readGlaze<BlueZObexMessageFolders>(
        'bluez_obex_message_access_list_folders',
        (out) => nativeBindings.bluez_obex_message_access_list_folders(
          _bridge.handle,
          path.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
      return result.folders;
    } finally {
      nativeFilters.dispose();
      path.dispose();
    }
  }

  @override
  Future<List<String>> messageAccessListFilterFields(
    String messageAccessPath,
  ) async {
    final path = NativeString(messageAccessPath);
    try {
      final result = _bridge.readGlaze<BlueZObexFilterFields>(
        'bluez_obex_message_access_list_filter_fields',
        (out) => nativeBindings.bluez_obex_message_access_list_filter_fields(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
      return result.fields;
    } finally {
      path.dispose();
    }
  }

  @override
  Future<List<BlueZObexMessageProps>> messageAccessListMessages(
    String messageAccessPath,
    String folder, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(messageAccessPath);
    final folderPtr = NativeString(folder);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _bridge.readGlaze<BlueZObexMessages>(
        'bluez_obex_message_access_list_messages',
        (out) => nativeBindings.bluez_obex_message_access_list_messages(
          _bridge.handle,
          path.pointer,
          folderPtr.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
        ),
      );
      return result.messages;
    } finally {
      nativeFilters.dispose();
      folderPtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<void> messageAccessUpdateInbox(String messageAccessPath) async {
    final path = NativeString(messageAccessPath);
    try {
      _bridge.checkStatus(
        'bluez_obex_message_access_update_inbox',
        nativeBindings.bluez_obex_message_access_update_inbox(
          _bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<BlueZObexTransferResult> messageAccessPushMessage(
    String messageAccessPath,
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) async {
    final path = NativeString(messageAccessPath);
    final sourceFilePtr = NativeString(sourceFile);
    final folderPtr = NativeString(folder);
    final nativeArgs = NativeStringMap(args);
    try {
      return _bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_message_access_push_message',
        (out) => nativeBindings.bluez_obex_message_access_push_message(
          _bridge.handle,
          path.pointer,
          sourceFilePtr.pointer,
          folderPtr.pointer,
          nativeArgs.keys,
          nativeArgs.values,
          nativeArgs.count,
          out,
        ),
      );
    } finally {
      nativeArgs.dispose();
      folderPtr.dispose();
      sourceFilePtr.dispose();
      path.dispose();
    }
  }

  @override
  Future<BlueZObexMessageProps> messageProperties(String messagePath) async {
    final path = NativeString(messagePath);
    try {
      return _bridge.readGlaze<BlueZObexMessageProps>(
        'bluez_obex_message_get_properties',
        (out) => nativeBindings.bluez_obex_message_get_properties(
          _bridge.handle,
          path.pointer,
          out,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<BlueZObexTransferResult> messageGet(
    String messagePath,
    String targetFile, {
    bool attachment = true,
  }) async {
    final path = NativeString(messagePath);
    final target = NativeString(targetFile);
    try {
      return _bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_message_get',
        (out) => nativeBindings.bluez_obex_message_get(
          _bridge.handle,
          path.pointer,
          target.pointer,
          attachment ? 1 : 0,
          out,
        ),
      );
    } finally {
      target.dispose();
      path.dispose();
    }
  }

  @override
  Future<void> messageSetRead(String messagePath, bool read) async {
    final path = NativeString(messagePath);
    try {
      _bridge.checkStatus(
        'bluez_obex_message_set_read',
        nativeBindings.bluez_obex_message_set_read(
          _bridge.handle,
          path.pointer,
          read ? 1 : 0,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> messageSetDeleted(String messagePath, bool deleted) async {
    final path = NativeString(messagePath);
    try {
      _bridge.checkStatus(
        'bluez_obex_message_set_deleted',
        nativeBindings.bluez_obex_message_set_deleted(
          _bridge.handle,
          path.pointer,
          deleted ? 1 : 0,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _bridge.dispose();
    _receivePort.close();
    await _receiveSubscription.cancel();
    await _eventsController.close();
  }
}

/// In-process endpoint that mirrors the BlueZ OBEX API for tests and examples.
class SimulatedBlueZObexBackend implements BlueZObexBackend {
  static const simulatedDevices = [
    BlueZDevice(
      address: 'AA:BB:CC:DD:EE:FF',
      name: 'Simulated phone',
      paired: true,
      connected: true,
      uuids: [
        '0000112f-0000-1000-8000-00805f9b34fb',
        '00001132-0000-1000-8000-00805f9b34fb',
      ],
    ),
  ];

  final Directory outputDirectory;
  final StreamController<BlueZObexEvent> _eventsController =
      StreamController<BlueZObexEvent>.broadcast();
  final Map<String, BlueZObexSessionProps> _sessions = {};
  final Map<String, BlueZObexPhonebookProps> _phonebooks = {};
  final Map<String, BlueZObexTransferProps> _transfers = {};
  final Map<String, BlueZObexMessageProps> _messages = {};
  final List<BlueZObexPhonebookEntry> _contacts = const [
    BlueZObexPhonebookEntry(vcard: '1.vcf', name: 'Ada Lovelace'),
    BlueZObexPhonebookEntry(vcard: '2.vcf', name: 'Grace Hopper'),
  ];
  bool _disposed = false;
  int _sessionCounter = 0;
  int _transferCounter = 0;

  SimulatedBlueZObexBackend({Directory? outputDirectory})
    : outputDirectory = outputDirectory ?? Directory.systemTemp {
    _eventsController.add(
      const BlueZObexEvent(BlueZObexEventType.initialSnapshotComplete, null),
    );
  }

  @override
  Stream<BlueZObexEvent> get events => _eventsController.stream;

  @override
  Future<List<BlueZDevice>> getDevices() async {
    return simulatedDevices;
  }

  @override
  Future<BlueZObexManagedObjects> getManagedObjects() async {
    return BlueZObexManagedObjects(
      sessions: _sessions.keys.toList(),
      transfers: _transfers.keys.toList(),
      phonebooks: _phonebooks.keys.toList(),
      messageAccesses: _sessions.keys.toList(),
      messages: _messages.keys.toList(),
    );
  }

  @override
  Future<BlueZObexSessionProps> createSession(
    String destination, {
    String target = 'pbap',
  }) async {
    if (target.isEmpty) {
      throw ArgumentError.value(target, 'target', 'Must not be empty');
    }
    final index = _sessionCounter++;
    final path = '/org/bluez/obex/client/session$index';
    final props = BlueZObexSessionProps(
      objectPath: path,
      source: '00:11:22:33:44:55',
      destination: destination,
      channel: 12,
      psm: 0x1001,
      target: target,
      root: '/telecom',
    );
    _sessions[path] = props;
    _phonebooks[path] = BlueZObexPhonebookProps(
      objectPath: path,
      folder: 'telecom/pb',
      databaseIdentifier: 'SIMULATED-DB',
      primaryCounter: '00000000000000000000000000000001',
      secondaryCounter: '00000000000000000000000000000002',
      fixedImageSize: true,
    );
    _messages['$path/message0'] = BlueZObexMessageProps(
      objectPath: '$path/message0',
      folder: 'telecom/msg/inbox',
      subject: 'Hello from simulated MAP',
      timestamp: '20260606T120000',
      sender: 'Ada',
      senderAddress: '+10000000000',
      recipient: 'Grace',
      recipientAddress: '+19999999999',
      type: 'sms-gsm',
      size: 32,
      text: true,
      status: 'complete',
      read: false,
    );
    for (final interfaceName in const [
      'org.bluez.obex.Session1',
      'org.bluez.obex.PhonebookAccess1',
      'org.bluez.obex.MessageAccess1',
      'org.bluez.obex.Message1',
    ]) {
      _emitAdded(
        interfaceName == 'org.bluez.obex.Message1' ? '$path/message0' : path,
        interfaceName,
      );
    }
    _eventsController.add(BlueZObexEvent(BlueZObexEventType.session, props));
    _eventsController.add(
      BlueZObexEvent(BlueZObexEventType.phonebook, _phonebooks[path]),
    );
    _eventsController.add(
      BlueZObexEvent(
        BlueZObexEventType.messageAccess,
        BlueZObexMessageAccessProps(
          objectPath: path,
          supportedTypes: const ['EMAIL', 'SMS_GSM', 'SMS_CDMA', 'MMS', 'IM'],
        ),
      ),
    );
    _eventsController.add(
      BlueZObexEvent(BlueZObexEventType.message, _messages['$path/message0']),
    );
    return props;
  }

  @override
  Future<void> removeSession(String sessionPath) async {
    final removedTransfers = _transfers.values
        .where((transfer) => transfer.session == sessionPath)
        .map((transfer) => transfer.objectPath)
        .toList();
    final removedMessages = _messages.keys
        .where((path) => path.startsWith('$sessionPath/'))
        .toList();
    _sessions.remove(sessionPath);
    _phonebooks.remove(sessionPath);
    _transfers.removeWhere((_, transfer) => transfer.session == sessionPath);
    _messages.removeWhere((path, _) => path.startsWith('$sessionPath/'));
    for (final path in removedTransfers) {
      _emitRemoved(path, 'org.bluez.obex.Transfer1');
    }
    for (final path in removedMessages) {
      _emitRemoved(path, 'org.bluez.obex.Message1');
    }
    _emitRemoved(sessionPath, 'org.bluez.obex.PhonebookAccess1');
    _emitRemoved(sessionPath, 'org.bluez.obex.MessageAccess1');
    _emitRemoved(sessionPath, 'org.bluez.obex.Session1');
  }

  @override
  Future<BlueZObexSessionProps> sessionProperties(String sessionPath) async {
    return _require(_sessions[sessionPath], sessionPath);
  }

  @override
  Future<String> sessionCapabilities(String sessionPath) async {
    _require(_sessions[sessionPath], sessionPath);
    return '<capabilities><service>PBAP</service><service>MAP</service></capabilities>';
  }

  @override
  Future<BlueZObexTransferProps> transferProperties(String transferPath) async {
    return _require(_transfers[transferPath], transferPath);
  }

  @override
  Future<void> transferCancel(String transferPath) async {
    _setTransferStatus(transferPath, 'cancelled');
  }

  @override
  Future<void> transferSuspend(String transferPath) async {
    _setTransferStatus(transferPath, 'suspended');
  }

  @override
  Future<void> transferResume(String transferPath) async {
    _setTransferStatus(transferPath, 'active');
  }

  @override
  Future<BlueZObexPhonebookProps> phonebookProperties(
    String phonebookPath,
  ) async {
    return _require(_phonebooks[phonebookPath], phonebookPath);
  }

  @override
  Future<void> phonebookSelect(
    String phonebookPath,
    String location,
    String phonebook,
  ) async {
    final current = _require(_phonebooks[phonebookPath], phonebookPath);
    _phonebooks[phonebookPath] = BlueZObexPhonebookProps(
      objectPath: current.objectPath,
      folder: '$location/$phonebook',
      databaseIdentifier: current.databaseIdentifier,
      primaryCounter: current.primaryCounter,
      secondaryCounter: current.secondaryCounter,
      fixedImageSize: current.fixedImageSize,
    );
  }

  @override
  Future<BlueZObexTransferResult> phonebookPullAll(
    String phonebookPath,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    final file = File(targetFile);
    file.writeAsStringSync(_contacts.map(_vcardFor).join('\n'));
    return _completeTransfer(phonebookPath, file.path, 'contacts.vcf');
  }

  @override
  Future<BlueZObexTransferResult> phonebookPull(
    String phonebookPath,
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    final entry = _contacts.where((candidate) => candidate.vcard == vcard);
    if (entry.isEmpty) {
      throw BlueZObexNativeException(vcard, -404);
    }
    final file = File(targetFile);
    file.writeAsStringSync(_vcardFor(entry.single));
    return _completeTransfer(phonebookPath, file.path, vcard);
  }

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookList(
    String phonebookPath, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    return _applyMaxCount(_contacts, filters);
  }

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookSearch(
    String phonebookPath,
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    final query = value.toLowerCase();
    return _applyMaxCount(
      _contacts
          .where((entry) => entry.name.toLowerCase().contains(query))
          .toList(),
      filters,
    );
  }

  @override
  Future<int> phonebookGetSize(String phonebookPath) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    return _contacts.length;
  }

  @override
  Future<void> phonebookUpdateVersion(String phonebookPath) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
  }

  @override
  Future<List<String>> phonebookListFilterFields(String phonebookPath) async {
    _require(_phonebooks[phonebookPath], phonebookPath);
    return const ['MaxCount', 'Offset', 'Fields'];
  }

  @override
  Future<BlueZObexMessageAccessProps> messageAccessProperties(
    String messageAccessPath,
  ) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
    return BlueZObexMessageAccessProps(
      objectPath: messageAccessPath,
      supportedTypes: const ['EMAIL', 'SMS_GSM', 'SMS_CDMA', 'MMS', 'IM'],
    );
  }

  @override
  Future<void> messageAccessSetFolder(
    String messageAccessPath,
    String folder,
  ) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
  }

  @override
  Future<List<BlueZObexMessageFolder>> messageAccessListFolders(
    String messageAccessPath, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
    return const [BlueZObexMessageFolder(name: 'inbox')];
  }

  @override
  Future<List<String>> messageAccessListFilterFields(
    String messageAccessPath,
  ) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
    return const ['MaxCount', 'Offset', 'SubjectLength'];
  }

  @override
  Future<List<BlueZObexMessageProps>> messageAccessListMessages(
    String messageAccessPath,
    String folder, {
    Map<String, Object?> filters = const {},
  }) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
    final messages = _messages.values
        .where(
          (message) => message.objectPath.startsWith('$messageAccessPath/'),
        )
        .where((message) => folder.isEmpty || message.folder.endsWith(folder))
        .toList();
    return _applyMaxCount(messages, filters);
  }

  @override
  Future<void> messageAccessUpdateInbox(String messageAccessPath) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
  }

  @override
  Future<BlueZObexTransferResult> messageAccessPushMessage(
    String messageAccessPath,
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) async {
    _require(_sessions[messageAccessPath], messageAccessPath);
    final path = '$messageAccessPath/message${_messages.length}';
    _messages[path] = BlueZObexMessageProps(
      objectPath: path,
      folder: folder,
      subject: 'Pushed message',
      timestamp: '20260606T121000',
      recipient: '${args['Recipient'] ?? ''}',
      type: 'sms-gsm',
      status: 'complete',
      sent: true,
    );
    _emitAdded(path, 'org.bluez.obex.Message1');
    _eventsController.add(
      BlueZObexEvent(BlueZObexEventType.message, _messages[path]),
    );
    return _completeTransfer(messageAccessPath, sourceFile, 'pushed.bmsg');
  }

  @override
  Future<BlueZObexMessageProps> messageProperties(String messagePath) async {
    return _require(_messages[messagePath], messagePath);
  }

  @override
  Future<BlueZObexTransferResult> messageGet(
    String messagePath,
    String targetFile, {
    bool attachment = true,
  }) async {
    final message = _require(_messages[messagePath], messagePath);
    final file = File(targetFile);
    file.writeAsStringSync(
      'BEGIN:BMSG\nSUBJECT:${message.subject}\nTEXT:Simulated text message\nEND:BMSG\n',
    );
    return _completeTransfer(messagePath, file.path, 'message.bmsg');
  }

  @override
  Future<void> messageSetRead(String messagePath, bool read) async {
    final message = _require(_messages[messagePath], messagePath);
    _messages[messagePath] = _copyMessage(message, read: read);
  }

  @override
  Future<void> messageSetDeleted(String messagePath, bool deleted) async {
    final message = _require(_messages[messagePath], messagePath);
    _messages[messagePath] = _copyMessage(message, deleted: deleted);
  }

  @override
  Future<void> dispose() {
    if (_disposed) {
      return Future.value();
    }
    _disposed = true;
    return _eventsController.close();
  }

  BlueZObexTransferResult _completeTransfer(
    String ownerPath,
    String filename,
    String name,
  ) {
    final transferPath = '$ownerPath/transfer${_transferCounter++}';
    final transfer = BlueZObexTransferProps(
      objectPath: transferPath,
      status: 'complete',
      session: ownerPath.contains('/message')
          ? ownerPath.substring(0, ownerPath.lastIndexOf('/'))
          : ownerPath,
      name: name,
      type: name.endsWith('.vcf') ? 'text/x-vcard' : 'text/x-bmessage',
      size: File(filename).existsSync() ? File(filename).lengthSync() : 0,
      transferred: File(filename).existsSync()
          ? File(filename).lengthSync()
          : 0,
      filename: filename,
    );
    _transfers[transferPath] = transfer;
    _emitAdded(transferPath, 'org.bluez.obex.Transfer1');
    _eventsController.add(
      BlueZObexEvent(BlueZObexEventType.transfer, transfer),
    );
    return BlueZObexTransferResult(
      transferPath: transferPath,
      properties: [
        const BlueZObexProperty(key: 'Status', value: 'complete'),
        BlueZObexProperty(key: 'Filename', value: filename),
      ],
    );
  }

  void _setTransferStatus(String transferPath, String status) {
    final transfer = _require(_transfers[transferPath], transferPath);
    final updated = BlueZObexTransferProps(
      objectPath: transfer.objectPath,
      status: status,
      session: transfer.session,
      name: transfer.name,
      type: transfer.type,
      time: transfer.time,
      size: transfer.size,
      transferred: transfer.transferred,
      filename: transfer.filename,
    );
    _transfers[transferPath] = updated;
    _eventsController.add(BlueZObexEvent(BlueZObexEventType.transfer, updated));
  }

  void _emitAdded(String objectPath, String interfaceName) {
    _eventsController.add(
      BlueZObexEvent(
        BlueZObexEventType.objectAdded,
        BlueZObexObjectAdded(
          objectPath: objectPath,
          interfaceName: interfaceName,
        ),
      ),
    );
  }

  void _emitRemoved(String objectPath, String interfaceName) {
    _eventsController.add(
      BlueZObexEvent(
        BlueZObexEventType.objectRemoved,
        BlueZObexObjectRemoved(
          objectPath: objectPath,
          interfaceName: interfaceName,
        ),
      ),
    );
  }
}

T _require<T>(T? value, String path) {
  if (value == null) {
    throw BlueZObexNativeException(path, -404);
  }
  return value;
}

List<T> _applyMaxCount<T>(List<T> values, Map<String, Object?> filters) {
  final raw = filters['MaxCount'];
  final count = raw is int ? raw : int.tryParse('${raw ?? ''}');
  if (count == null || count <= 0 || count >= values.length) {
    return values;
  }
  return values.take(count).toList();
}

String _vcardFor(BlueZObexPhonebookEntry entry) {
  return 'BEGIN:VCARD\nVERSION:3.0\nFN:${entry.name}\nUID:${entry.vcard}\nEND:VCARD\n';
}

BlueZObexMessageProps _copyMessage(
  BlueZObexMessageProps message, {
  bool? read,
  bool? deleted,
}) {
  return BlueZObexMessageProps(
    objectPath: message.objectPath,
    folder: message.folder,
    subject: message.subject,
    timestamp: message.timestamp,
    sender: message.sender,
    senderAddress: message.senderAddress,
    replyTo: message.replyTo,
    recipient: message.recipient,
    recipientAddress: message.recipientAddress,
    type: message.type,
    size: message.size,
    text: message.text,
    status: message.status,
    attachmentSize: message.attachmentSize,
    priority: message.priority,
    read: read ?? message.read,
    deleted: deleted ?? message.deleted,
    sent: message.sent,
    protected: message.protected,
    deliveryStatus: message.deliveryStatus,
    conversationId: message.conversationId,
    conversationName: message.conversationName,
    direction: message.direction,
    attachmentMimeTypes: message.attachmentMimeTypes,
  );
}
