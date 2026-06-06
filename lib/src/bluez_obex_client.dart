import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:isolate';
import 'dart:typed_data';

import 'ffi/types.dart';
import 'native_bridge.dart';

class BlueZObexClient {
  final BlueZObexNativeBridge _bridge;
  final ReceivePort _receivePort;
  final StreamController<BlueZObexEvent> _eventsController;

  BlueZObexClient._(this._bridge, this._receivePort, this._eventsController);

  static Future<BlueZObexClient> connect() async {
    initializeDartDl();
    final receivePort = ReceivePort();
    final eventsController = StreamController<BlueZObexEvent>.broadcast();
    receivePort.listen((dynamic data) {
      if (data is Uint8List) {
        eventsController.add(decodeNativeEvent(data));
      } else if (data is List<int>) {
        eventsController.add(decodeNativeEvent(Uint8List.fromList(data)));
      }
    });

    final handle = nativeBindings.bluez_obex_client_create(
      receivePort.sendPort.nativePort,
    );
    if (handle == ffi.nullptr) {
      receivePort.close();
      await eventsController.close();
      throw const BlueZObexNativeException('bluez_obex_client_create', -1);
    }

    return BlueZObexClient._(
      BlueZObexNativeBridge(handle),
      receivePort,
      eventsController,
    );
  }

  Stream<BlueZObexEvent> get events => _eventsController.stream;

  Future<BlueZObexManagedObjects> getManagedObjects() async {
    return _bridge.readGlaze<BlueZObexManagedObjects>(
      'bluez_obex_get_managed_objects',
      (out, capacity) => nativeBindings.bluez_obex_get_managed_objects(
        _bridge.handle,
        out,
        capacity,
      ),
    );
  }

  Future<BlueZObexSession> createSession(
    String destination, {
    String target = '',
  }) async {
    final destinationPtr = NativeString(destination);
    final targetPtr = NativeString(target);
    try {
      final props = _bridge.readGlaze<BlueZObexSessionProps>(
        'bluez_obex_client_create_session',
        (out, capacity) => nativeBindings.bluez_obex_client_create_session(
          _bridge.handle,
          destinationPtr.pointer,
          targetPtr.pointer,
          out,
          capacity,
        ),
      );
      return BlueZObexSession._(this, props.objectPath, props);
    } finally {
      targetPtr.dispose();
      destinationPtr.dispose();
    }
  }

  BlueZObexSession session(String objectPath) {
    return BlueZObexSession._(this, objectPath, null);
  }

  BlueZObexPhonebook phonebook(String objectPath) {
    return BlueZObexPhonebook._(this, objectPath);
  }

  BlueZObexMessageAccess messageAccess(String objectPath) {
    return BlueZObexMessageAccess._(this, objectPath);
  }

  BlueZObexMessage message(String objectPath, [BlueZObexMessageProps? props]) {
    return BlueZObexMessage._(this, objectPath, props);
  }

  Future<void> dispose() async {
    _bridge.dispose();
    _receivePort.close();
    await _eventsController.close();
  }
}

class BlueZObexSession {
  final BlueZObexClient _client;
  final String objectPath;
  BlueZObexSessionProps? _lastProps;

  BlueZObexSession._(this._client, this.objectPath, this._lastProps);

  BlueZObexSessionProps? get lastProperties => _lastProps;

  BlueZObexPhonebook get phonebook => _client.phonebook(objectPath);

  BlueZObexMessageAccess get messageAccess => _client.messageAccess(objectPath);

  Future<BlueZObexSessionProps> properties() async {
    final path = NativeString(objectPath);
    try {
      final props = _client._bridge.readGlaze<BlueZObexSessionProps>(
        'bluez_obex_session_get_properties',
        (out, capacity) => nativeBindings.bluez_obex_session_get_properties(
          _client._bridge.handle,
          path.pointer,
          out,
          capacity,
        ),
      );
      _lastProps = props;
      return props;
    } finally {
      path.dispose();
    }
  }

  Future<String> capabilities() async {
    final path = NativeString(objectPath);
    try {
      return _client._bridge.readUtf8(
        'bluez_obex_session_get_capabilities',
        (out, capacity) => nativeBindings.bluez_obex_session_get_capabilities(
          _client._bridge.handle,
          path.pointer,
          out,
          capacity,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  Future<void> remove() async {
    final path = NativeString(objectPath);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_client_remove_session',
        nativeBindings.bluez_obex_client_remove_session(
          _client._bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }
}

class BlueZObexPhonebook {
  final BlueZObexClient _client;
  final String objectPath;

  BlueZObexPhonebook._(this._client, this.objectPath);

  Future<BlueZObexPhonebookProps> properties() async {
    final path = NativeString(objectPath);
    try {
      return _client._bridge.readGlaze<BlueZObexPhonebookProps>(
        'bluez_obex_phonebook_get_properties',
        (out, capacity) => nativeBindings.bluez_obex_phonebook_get_properties(
          _client._bridge.handle,
          path.pointer,
          out,
          capacity,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  Future<void> select(String location, String phonebook) async {
    final path = NativeString(objectPath);
    final locationPtr = NativeString(location);
    final phonebookPtr = NativeString(phonebook);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_phonebook_select',
        nativeBindings.bluez_obex_phonebook_select(
          _client._bridge.handle,
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

  Future<BlueZObexTransferResult> pullAll(
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(objectPath);
    final target = NativeString(targetFile);
    final nativeFilters = NativeStringMap(filters);
    try {
      return _client._bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_phonebook_pull_all',
        (out, capacity) => nativeBindings.bluez_obex_phonebook_pull_all(
          _client._bridge.handle,
          path.pointer,
          target.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
          capacity,
        ),
      );
    } finally {
      nativeFilters.dispose();
      target.dispose();
      path.dispose();
    }
  }

  Future<List<BlueZObexPhonebookEntry>> list({
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(objectPath);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _client._bridge.readGlaze<BlueZObexPhonebookEntries>(
        'bluez_obex_phonebook_list',
        (out, capacity) => nativeBindings.bluez_obex_phonebook_list(
          _client._bridge.handle,
          path.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
          capacity,
        ),
      );
      return result.entries;
    } finally {
      nativeFilters.dispose();
      path.dispose();
    }
  }

  Future<List<BlueZObexPhonebookEntry>> search(
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(objectPath);
    final fieldPtr = NativeString(field);
    final valuePtr = NativeString(value);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _client._bridge.readGlaze<BlueZObexPhonebookEntries>(
        'bluez_obex_phonebook_search',
        (out, capacity) => nativeBindings.bluez_obex_phonebook_search(
          _client._bridge.handle,
          path.pointer,
          fieldPtr.pointer,
          valuePtr.pointer,
          nativeFilters.keys,
          nativeFilters.values,
          nativeFilters.count,
          out,
          capacity,
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

  Future<int> getSize() async {
    final path = NativeString(objectPath);
    try {
      final size = nativeBindings.bluez_obex_phonebook_get_size(
        _client._bridge.handle,
        path.pointer,
      );
      _client._bridge.checkStatus('bluez_obex_phonebook_get_size', size);
      return size;
    } finally {
      path.dispose();
    }
  }

  Future<void> updateVersion() async {
    final path = NativeString(objectPath);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_phonebook_update_version',
        nativeBindings.bluez_obex_phonebook_update_version(
          _client._bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  Future<List<String>> listFilterFields() async {
    final path = NativeString(objectPath);
    try {
      final result = _client._bridge.readGlaze<BlueZObexFilterFields>(
        'bluez_obex_phonebook_list_filter_fields',
        (out, capacity) =>
            nativeBindings.bluez_obex_phonebook_list_filter_fields(
              _client._bridge.handle,
              path.pointer,
              out,
              capacity,
            ),
      );
      return result.fields;
    } finally {
      path.dispose();
    }
  }
}

class BlueZObexMessageAccess {
  final BlueZObexClient _client;
  final String objectPath;

  BlueZObexMessageAccess._(this._client, this.objectPath);

  Future<void> setFolder(String folder) async {
    final path = NativeString(objectPath);
    final folderPtr = NativeString(folder);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_message_access_set_folder',
        nativeBindings.bluez_obex_message_access_set_folder(
          _client._bridge.handle,
          path.pointer,
          folderPtr.pointer,
        ),
      );
    } finally {
      folderPtr.dispose();
      path.dispose();
    }
  }

  Future<List<BlueZObexMessageFolder>> listFolders({
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(objectPath);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _client._bridge.readGlaze<BlueZObexMessageFolders>(
        'bluez_obex_message_access_list_folders',
        (out, capacity) =>
            nativeBindings.bluez_obex_message_access_list_folders(
              _client._bridge.handle,
              path.pointer,
              nativeFilters.keys,
              nativeFilters.values,
              nativeFilters.count,
              out,
              capacity,
            ),
      );
      return result.folders;
    } finally {
      nativeFilters.dispose();
      path.dispose();
    }
  }

  Future<List<String>> listFilterFields() async {
    final path = NativeString(objectPath);
    try {
      final result = _client._bridge.readGlaze<BlueZObexFilterFields>(
        'bluez_obex_message_access_list_filter_fields',
        (out, capacity) =>
            nativeBindings.bluez_obex_message_access_list_filter_fields(
              _client._bridge.handle,
              path.pointer,
              out,
              capacity,
            ),
      );
      return result.fields;
    } finally {
      path.dispose();
    }
  }

  Future<List<BlueZObexMessage>> listMessages(
    String folder, {
    Map<String, Object?> filters = const {},
  }) async {
    final path = NativeString(objectPath);
    final folderPtr = NativeString(folder);
    final nativeFilters = NativeStringMap(filters);
    try {
      final result = _client._bridge.readGlaze<BlueZObexMessages>(
        'bluez_obex_message_access_list_messages',
        (out, capacity) =>
            nativeBindings.bluez_obex_message_access_list_messages(
              _client._bridge.handle,
              path.pointer,
              folderPtr.pointer,
              nativeFilters.keys,
              nativeFilters.values,
              nativeFilters.count,
              out,
              capacity,
            ),
      );
      return [
        for (final props in result.messages)
          BlueZObexMessage._(_client, props.objectPath, props),
      ];
    } finally {
      nativeFilters.dispose();
      folderPtr.dispose();
      path.dispose();
    }
  }

  Future<void> updateInbox() async {
    final path = NativeString(objectPath);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_message_access_update_inbox',
        nativeBindings.bluez_obex_message_access_update_inbox(
          _client._bridge.handle,
          path.pointer,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  Future<BlueZObexTransferResult> pushMessage(
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) async {
    final path = NativeString(objectPath);
    final sourceFilePtr = NativeString(sourceFile);
    final folderPtr = NativeString(folder);
    final nativeArgs = NativeStringMap(args);
    try {
      return _client._bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_message_access_push_message',
        (out, capacity) =>
            nativeBindings.bluez_obex_message_access_push_message(
              _client._bridge.handle,
              path.pointer,
              sourceFilePtr.pointer,
              folderPtr.pointer,
              nativeArgs.keys,
              nativeArgs.values,
              nativeArgs.count,
              out,
              capacity,
            ),
      );
    } finally {
      nativeArgs.dispose();
      folderPtr.dispose();
      sourceFilePtr.dispose();
      path.dispose();
    }
  }
}

class BlueZObexMessage {
  final BlueZObexClient _client;
  final String objectPath;
  BlueZObexMessageProps? _lastProps;

  BlueZObexMessage._(this._client, this.objectPath, this._lastProps);

  BlueZObexMessageProps? get lastProperties => _lastProps;

  Future<BlueZObexMessageProps> properties() async {
    final path = NativeString(objectPath);
    try {
      final props = _client._bridge.readGlaze<BlueZObexMessageProps>(
        'bluez_obex_message_get_properties',
        (out, capacity) => nativeBindings.bluez_obex_message_get_properties(
          _client._bridge.handle,
          path.pointer,
          out,
          capacity,
        ),
      );
      _lastProps = props;
      return props;
    } finally {
      path.dispose();
    }
  }

  Future<BlueZObexTransferResult> get(
    String targetFile, {
    bool attachment = true,
  }) async {
    final path = NativeString(objectPath);
    final target = NativeString(targetFile);
    try {
      return _client._bridge.readGlaze<BlueZObexTransferResult>(
        'bluez_obex_message_get',
        (out, capacity) => nativeBindings.bluez_obex_message_get(
          _client._bridge.handle,
          path.pointer,
          target.pointer,
          attachment ? 1 : 0,
          out,
          capacity,
        ),
      );
    } finally {
      target.dispose();
      path.dispose();
    }
  }

  Future<void> setRead(bool read) async {
    final path = NativeString(objectPath);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_message_set_read',
        nativeBindings.bluez_obex_message_set_read(
          _client._bridge.handle,
          path.pointer,
          read ? 1 : 0,
        ),
      );
    } finally {
      path.dispose();
    }
  }

  Future<void> setDeleted(bool deleted) async {
    final path = NativeString(objectPath);
    try {
      _client._bridge.checkStatus(
        'bluez_obex_message_set_deleted',
        nativeBindings.bluez_obex_message_set_deleted(
          _client._bridge.handle,
          path.pointer,
          deleted ? 1 : 0,
        ),
      );
    } finally {
      path.dispose();
    }
  }
}
