/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

part of '../bluez_obex_client.dart';

/// Owns the native connection in a dedicated isolate. Always call [dispose].
class NativeBlueZObexBackend implements BlueZObexBackend {
  final _messages = ReceivePort();
  final _ready = Completer<SendPort>();
  final _exited = Completer<void>();
  final _pending = <int, Completer<Object?>>{};
  final _events = StreamController<BlueZObexEvent>.broadcast();
  late final Isolate _isolate;
  int _nextId = 0;
  Future<void>? _disposeFuture;

  NativeBlueZObexBackend._() {
    _messages.listen(_onMessage);
  }

  static Future<NativeBlueZObexBackend> connect() async {
    final backend = NativeBlueZObexBackend._();
    try {
      backend._isolate = await Isolate.spawn(
        _nativeWorker,
        backend._messages.sendPort,
        onExit: backend._messages.sendPort,
        onError: backend._messages.sendPort,
      );
      await backend._ready.future;
      return backend;
    } catch (_) {
      backend._messages.close();
      unawaited(backend._events.close());
      rethrow;
    }
  }

  static Future<List<BlueZDevice>> queryDevices() =>
      Isolate.run(_LocalNativeBlueZObexBackend.queryDevices);

  @override
  Stream<BlueZObexEvent> get events => _events.stream;

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      _ready.complete(message);
    } else if (message is BlueZObexEvent) {
      if (!_events.isClosed) _events.add(message);
      if (message.type == BlueZObexEventType.streamDone) {
        unawaited(_events.close());
      }
    } else if (message is List && message.length == 3) {
      final stack = StackTrace.fromString(message[2] as String);
      if (message[0] == 'startup') {
        _ready.completeError(message[1] as Object, stack);
      } else if (!_events.isClosed) {
        _events.addError(message[1] as Object, stack);
      }
    } else if (message is List && message.length == 4) {
      final completer = _pending.remove(message[0]);
      if (message[2] == null) {
        completer?.complete(message[1]);
      } else {
        completer?.completeError(
          message[2] as Object,
          StackTrace.fromString(message[3] as String),
        );
      }
    } else {
      final error = message is List
          ? StateError('Native worker failed: ${message.join('\n')}')
          : StateError('Native worker exited');
      if (!_ready.isCompleted) _ready.completeError(error);
      for (final completer in _pending.values) {
        completer.completeError(error);
      }
      _pending.clear();
      if (message == null) {
        _messages.close();
        unawaited(_events.close());
        _exited.complete();
      }
    }
  }

  Future<T> _call<T>(String operation, List<Object?> arguments) {
    if (_disposeFuture != null || _exited.isCompleted) {
      return Future.error(StateError('OBEX client is disposed'));
    }
    return _request<T>(operation, arguments);
  }

  Future<T> _request<T>(String operation, List<Object?> arguments) async {
    final port = await _ready.future;
    final id = _nextId++;
    final result = Completer<Object?>();
    _pending[id] = result;
    try {
      port.send([id, operation, arguments]);
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
    return (await result.future) as T;
  }

  @override
  Future<void> dispose() => _disposeFuture ??= _dispose();

  Future<void> _dispose() async {
    if (_exited.isCompleted) return;
    try {
      await _request<void>('dispose', []);
      await _exited.future;
    } finally {
      _isolate.kill(priority: Isolate.immediate);
      _messages.close();
      unawaited(_events.close());
    }
  }

  @override
  Future<List<BlueZDevice>> getDevices() =>
      _call<List<BlueZDevice>>('getDevices', []);

  @override
  Future<BlueZObexManagedObjects> getManagedObjects() =>
      _call<BlueZObexManagedObjects>('getManagedObjects', []);

  @override
  Future<BlueZObexSessionProps> createSession(
    String destination, {
    String target = 'pbap',
  }) => _call<BlueZObexSessionProps>('createSession', [destination, target]);

  @override
  Future<void> removeSession(String sessionPath) =>
      _call<void>('removeSession', [sessionPath]);

  @override
  Future<BlueZObexSessionProps> sessionProperties(String sessionPath) =>
      _call<BlueZObexSessionProps>('sessionProperties', [sessionPath]);

  @override
  Future<String> sessionCapabilities(String sessionPath) =>
      _call<String>('sessionCapabilities', [sessionPath]);

  @override
  Future<BlueZObexTransferProps> transferProperties(String transferPath) =>
      _call<BlueZObexTransferProps>('transferProperties', [transferPath]);

  @override
  Future<void> transferCancel(String transferPath) =>
      _call<void>('transferCancel', [transferPath]);

  @override
  Future<void> transferSuspend(String transferPath) =>
      _call<void>('transferSuspend', [transferPath]);

  @override
  Future<void> transferResume(String transferPath) =>
      _call<void>('transferResume', [transferPath]);

  @override
  Future<BlueZObexPhonebookProps> phonebookProperties(String phonebookPath) =>
      _call<BlueZObexPhonebookProps>('phonebookProperties', [phonebookPath]);

  @override
  Future<void> phonebookSelect(
    String phonebookPath,
    String location,
    String phonebook,
  ) => _call<void>('phonebookSelect', [phonebookPath, location, phonebook]);

  @override
  Future<BlueZObexTransferResult> phonebookPullAll(
    String phonebookPath,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) => _call<BlueZObexTransferResult>('phonebookPullAll', [
    phonebookPath,
    targetFile,
    filters,
  ]);

  @override
  Future<BlueZObexTransferResult> phonebookPull(
    String phonebookPath,
    String vcard,
    String targetFile, {
    Map<String, Object?> filters = const {},
  }) => _call<BlueZObexTransferResult>('phonebookPull', [
    phonebookPath,
    vcard,
    targetFile,
    filters,
  ]);

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookList(
    String phonebookPath, {
    Map<String, Object?> filters = const {},
  }) => _call<List<BlueZObexPhonebookEntry>>('phonebookList', [
    phonebookPath,
    filters,
  ]);

  @override
  Future<List<BlueZObexPhonebookEntry>> phonebookSearch(
    String phonebookPath,
    String field,
    String value, {
    Map<String, Object?> filters = const {},
  }) => _call<List<BlueZObexPhonebookEntry>>('phonebookSearch', [
    phonebookPath,
    field,
    value,
    filters,
  ]);

  @override
  Future<int> phonebookGetSize(String phonebookPath) =>
      _call<int>('phonebookGetSize', [phonebookPath]);

  @override
  Future<void> phonebookUpdateVersion(String phonebookPath) =>
      _call<void>('phonebookUpdateVersion', [phonebookPath]);

  @override
  Future<List<String>> phonebookListFilterFields(String phonebookPath) =>
      _call<List<String>>('phonebookListFilterFields', [phonebookPath]);

  @override
  Future<BlueZObexMessageAccessProps> messageAccessProperties(
    String messageAccessPath,
  ) => _call<BlueZObexMessageAccessProps>('messageAccessProperties', [
    messageAccessPath,
  ]);

  @override
  Future<void> messageAccessSetFolder(
    String messageAccessPath,
    String folder,
  ) => _call<void>('messageAccessSetFolder', [messageAccessPath, folder]);

  @override
  Future<List<BlueZObexMessageFolder>> messageAccessListFolders(
    String messageAccessPath, {
    Map<String, Object?> filters = const {},
  }) => _call<List<BlueZObexMessageFolder>>('messageAccessListFolders', [
    messageAccessPath,
    filters,
  ]);

  @override
  Future<List<String>> messageAccessListFilterFields(
    String messageAccessPath,
  ) =>
      _call<List<String>>('messageAccessListFilterFields', [messageAccessPath]);

  @override
  Future<List<BlueZObexMessageProps>> messageAccessListMessages(
    String messageAccessPath,
    String folder, {
    Map<String, Object?> filters = const {},
  }) => _call<List<BlueZObexMessageProps>>('messageAccessListMessages', [
    messageAccessPath,
    folder,
    filters,
  ]);

  @override
  Future<void> messageAccessUpdateInbox(String messageAccessPath) =>
      _call<void>('messageAccessUpdateInbox', [messageAccessPath]);

  @override
  Future<BlueZObexTransferResult> messageAccessPushMessage(
    String messageAccessPath,
    String sourceFile,
    String folder, {
    Map<String, Object?> args = const {},
  }) => _call<BlueZObexTransferResult>('messageAccessPushMessage', [
    messageAccessPath,
    sourceFile,
    folder,
    args,
  ]);

  @override
  Future<BlueZObexMessageProps> messageProperties(String messagePath) =>
      _call<BlueZObexMessageProps>('messageProperties', [messagePath]);

  @override
  Future<BlueZObexTransferResult> messageGet(
    String messagePath,
    String targetFile, {
    bool attachment = true,
  }) => _call<BlueZObexTransferResult>('messageGet', [
    messagePath,
    targetFile,
    attachment,
  ]);

  @override
  Future<void> messageSetRead(String messagePath, bool read) =>
      _call<void>('messageSetRead', [messagePath, read]);

  @override
  Future<void> messageSetDeleted(String messagePath, bool deleted) =>
      _call<void>('messageSetDeleted', [messagePath, deleted]);
}

Future<void> _nativeWorker(SendPort parent) async {
  final commands = ReceivePort();
  _LocalNativeBlueZObexBackend? backend;
  StreamSubscription<BlueZObexEvent>? events;
  try {
    backend = await _LocalNativeBlueZObexBackend.connect();
    events = backend.events.listen(
      parent.send,
      onError: (Object error, StackTrace stack) =>
          parent.send(['eventError', error, stack.toString()]),
    );
    parent.send(commands.sendPort);
    await for (final message in commands) {
      final request = message as List;
      final id = request[0] as int;
      final operation = request[1] as String;
      final arguments = request[2] as List;
      try {
        final Object? result;
        switch (operation) {
          case 'getDevices':
            result = await backend.getDevices();
            break;
          case 'getManagedObjects':
            result = await backend.getManagedObjects();
            break;
          case 'createSession':
            result = await backend.createSession(
              arguments[0] as String,
              target: arguments[1] as String,
            );
            break;
          case 'removeSession':
            await backend.removeSession(arguments[0] as String);
            result = null;
            break;
          case 'sessionProperties':
            result = await backend.sessionProperties(arguments[0] as String);
            break;
          case 'sessionCapabilities':
            result = await backend.sessionCapabilities(arguments[0] as String);
            break;
          case 'transferProperties':
            result = await backend.transferProperties(arguments[0] as String);
            break;
          case 'transferCancel':
            await backend.transferCancel(arguments[0] as String);
            result = null;
            break;
          case 'transferSuspend':
            await backend.transferSuspend(arguments[0] as String);
            result = null;
            break;
          case 'transferResume':
            await backend.transferResume(arguments[0] as String);
            result = null;
            break;
          case 'phonebookProperties':
            result = await backend.phonebookProperties(arguments[0] as String);
            break;
          case 'phonebookSelect':
            await backend.phonebookSelect(
              arguments[0] as String,
              arguments[1] as String,
              arguments[2] as String,
            );
            result = null;
            break;
          case 'phonebookPullAll':
            result = await backend.phonebookPullAll(
              arguments[0] as String,
              arguments[1] as String,
              filters: arguments[2] as Map<String, Object?>,
            );
            break;
          case 'phonebookPull':
            result = await backend.phonebookPull(
              arguments[0] as String,
              arguments[1] as String,
              arguments[2] as String,
              filters: arguments[3] as Map<String, Object?>,
            );
            break;
          case 'phonebookList':
            result = await backend.phonebookList(
              arguments[0] as String,
              filters: arguments[1] as Map<String, Object?>,
            );
            break;
          case 'phonebookSearch':
            result = await backend.phonebookSearch(
              arguments[0] as String,
              arguments[1] as String,
              arguments[2] as String,
              filters: arguments[3] as Map<String, Object?>,
            );
            break;
          case 'phonebookGetSize':
            result = await backend.phonebookGetSize(arguments[0] as String);
            break;
          case 'phonebookUpdateVersion':
            await backend.phonebookUpdateVersion(arguments[0] as String);
            result = null;
            break;
          case 'phonebookListFilterFields':
            result = await backend.phonebookListFilterFields(
              arguments[0] as String,
            );
            break;
          case 'messageAccessProperties':
            result = await backend.messageAccessProperties(
              arguments[0] as String,
            );
            break;
          case 'messageAccessSetFolder':
            await backend.messageAccessSetFolder(
              arguments[0] as String,
              arguments[1] as String,
            );
            result = null;
            break;
          case 'messageAccessListFolders':
            result = await backend.messageAccessListFolders(
              arguments[0] as String,
              filters: arguments[1] as Map<String, Object?>,
            );
            break;
          case 'messageAccessListFilterFields':
            result = await backend.messageAccessListFilterFields(
              arguments[0] as String,
            );
            break;
          case 'messageAccessListMessages':
            result = await backend.messageAccessListMessages(
              arguments[0] as String,
              arguments[1] as String,
              filters: arguments[2] as Map<String, Object?>,
            );
            break;
          case 'messageAccessUpdateInbox':
            await backend.messageAccessUpdateInbox(arguments[0] as String);
            result = null;
            break;
          case 'messageAccessPushMessage':
            result = await backend.messageAccessPushMessage(
              arguments[0] as String,
              arguments[1] as String,
              arguments[2] as String,
              args: arguments[3] as Map<String, Object?>,
            );
            break;
          case 'messageProperties':
            result = await backend.messageProperties(arguments[0] as String);
            break;
          case 'messageGet':
            result = await backend.messageGet(
              arguments[0] as String,
              arguments[1] as String,
              attachment: arguments[2] as bool,
            );
            break;
          case 'messageSetRead':
            await backend.messageSetRead(
              arguments[0] as String,
              arguments[1] as bool,
            );
            result = null;
            break;
          case 'messageSetDeleted':
            await backend.messageSetDeleted(
              arguments[0] as String,
              arguments[1] as bool,
            );
            result = null;
            break;
          case 'dispose':
            await backend.dispose();
            result = null;
            break;
          default:
            throw ArgumentError('Unknown operation: $operation');
        }
        parent.send([id, result, null, null]);
      } catch (error, stack) {
        parent.send([id, null, error, stack.toString()]);
      }
      if (operation == 'dispose') break;
    }
  } catch (error, stack) {
    parent.send(['startup', error, stack.toString()]);
  } finally {
    commands.close();
    await events?.cancel();
    await backend?.dispose();
  }
}
