/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../bluez_obex_native_bindings_generated.dart';
import 'ffi/codec.dart';
import 'ffi/types.dart';

import 'internal/library_loader.dart';

final ffi.DynamicLibrary _dylib = loadBluezObexNative();

final ffi.NativeFinalizer _clientFinalizer = ffi.NativeFinalizer(
  _dylib.lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
    'bluez_obex_client_destroy',
  ),
);

final BluezObexNativeBindings nativeBindings = BluezObexNativeBindings(_dylib);

bool _dartDlInitialized = false;

void initializeDartDl() {
  if (_dartDlInitialized) {
    return;
  }
  nativeBindings.bluez_obex_init(ffi.NativeApi.initializeApiDLData);
  _dartDlInitialized = true;
}

class BlueZObexNativeException implements Exception {
  final String operation;
  final int code;

  final String? name;
  final String? message;

  const BlueZObexNativeException(
    this.operation,
    this.code, {
    this.name,
    this.message,
  });

  @override
  String toString() =>
      'BlueZObexNativeException($operation failed: ${name ?? code}${message == null ? '' : ': $message'})';
}

class BlueZObexNativeBridge implements ffi.Finalizable {
  final ffi.Pointer<ffi.Void> handle;
  bool _disposed = false;

  BlueZObexNativeBridge(this.handle) {
    _clientFinalizer.attach(this, handle, detach: this);
  }

  Uint8List readBytes(
    String operation,
    int Function(ffi.Pointer<ffi.Pointer<ffi.Uint8>> out) call,
  ) {
    return readNativeBytes(operation, call);
  }

  T readGlaze<T>(
    String operation,
    int Function(ffi.Pointer<ffi.Pointer<ffi.Uint8>> out) call,
  ) {
    return GlazeCodec.decode<T>(readBytes(operation, call), 0);
  }

  String readUtf8(
    String operation,
    int Function(ffi.Pointer<ffi.Pointer<ffi.Uint8>> out) call,
  ) {
    return utf8.decode(readBytes(operation, call));
  }

  void checkStatus(String operation, int code) {
    _checkResult(operation, code, allowZero: true);
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _clientFinalizer.detach(this);
    nativeBindings.bluez_obex_client_destroy(handle);
  }
}

Uint8List readNativeBytes(
  String operation,
  int Function(ffi.Pointer<ffi.Pointer<ffi.Uint8>> out) call,
) {
  final out = calloc<ffi.Pointer<ffi.Uint8>>();
  try {
    final written = call(out);
    _checkResult(operation, written, allowZero: true);
    if (written > 0 && out.value == ffi.nullptr) {
      throw StateError('$operation returned a null result buffer');
    }
    return written == 0
        ? Uint8List(0)
        : Uint8List.fromList(out.value.asTypedList(written));
  } finally {
    nativeBindings.bluez_obex_free(out.value.cast());
    calloc.free(out);
  }
}

T readNativeGlaze<T>(
  String operation,
  int Function(ffi.Pointer<ffi.Pointer<ffi.Uint8>> out) call,
) {
  return GlazeCodec.decode<T>(readNativeBytes(operation, call), 0);
}

class NativeString implements ffi.Finalizable {
  final ffi.Pointer<ffi.Char> pointer;

  NativeString(String value)
    : pointer = value.toNativeUtf8(allocator: calloc).cast<ffi.Char>();

  void dispose() {
    calloc.free(pointer);
  }
}

class NativeStringMap implements ffi.Finalizable {
  final ffi.Pointer<ffi.Pointer<ffi.Char>> keys;
  final ffi.Pointer<ffi.Pointer<ffi.Char>> values;
  final int count;
  final List<ffi.Pointer<ffi.Char>> _ownedStrings;

  NativeStringMap(Map<String, Object?> map)
    : count = map.length,
      keys = map.isEmpty
          ? ffi.nullptr
          : calloc<ffi.Pointer<ffi.Char>>(map.length),
      values = map.isEmpty
          ? ffi.nullptr
          : calloc<ffi.Pointer<ffi.Char>>(map.length),
      _ownedStrings = [] {
    var index = 0;
    for (final entry in map.entries) {
      final key = entry.key.toNativeUtf8(allocator: calloc).cast<ffi.Char>();
      final value = _filterValueToString(
        entry.value,
      ).toNativeUtf8(allocator: calloc).cast<ffi.Char>();
      _ownedStrings.addAll([key, value]);
      keys[index] = key;
      values[index] = value;
      index += 1;
    }
  }

  void dispose() {
    for (final pointer in _ownedStrings) {
      calloc.free(pointer);
    }
    if (keys != ffi.nullptr) {
      calloc.free(keys);
    }
    if (values != ffi.nullptr) {
      calloc.free(values);
    }
  }

  static String _filterValueToString(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is Iterable) {
      return value.join(',');
    }
    return value.toString();
  }
}

BlueZObexEvent decodeNativeEvent(Uint8List message) {
  if (message.isEmpty) {
    return const BlueZObexEvent(BlueZObexEventType.unknown, null);
  }

  final type = BlueZObexEventType.fromDiscriminator(message[0]);
  if (type == BlueZObexEventType.initialSnapshotComplete ||
      type == BlueZObexEventType.streamDone) {
    return BlueZObexEvent(type, null);
  }

  final payload = switch (type) {
    BlueZObexEventType.session => GlazeCodec.decode<BlueZObexSessionProps>(
      message,
      1,
    ),
    BlueZObexEventType.transfer => GlazeCodec.decode<BlueZObexTransferProps>(
      message,
      1,
    ),
    BlueZObexEventType.phonebook => GlazeCodec.decode<BlueZObexPhonebookProps>(
      message,
      1,
    ),
    BlueZObexEventType.phonebookEntries =>
      GlazeCodec.decode<BlueZObexPhonebookEntries>(message, 1),
    BlueZObexEventType.messageFolders =>
      GlazeCodec.decode<BlueZObexMessageFolders>(message, 1),
    BlueZObexEventType.message => GlazeCodec.decode<BlueZObexMessageProps>(
      message,
      1,
    ),
    BlueZObexEventType.messageAccess =>
      GlazeCodec.decode<BlueZObexMessageAccessProps>(message, 1),
    BlueZObexEventType.transferResult =>
      GlazeCodec.decode<BlueZObexTransferResult>(message, 1),
    BlueZObexEventType.error => GlazeCodec.decode<BlueZObexError>(message, 1),
    BlueZObexEventType.objectAdded => GlazeCodec.decode<BlueZObexObjectAdded>(
      message,
      1,
    ),
    BlueZObexEventType.objectRemoved =>
      GlazeCodec.decode<BlueZObexObjectRemoved>(message, 1),
    BlueZObexEventType.unknown => message.sublist(1),
    _ => message.sublist(1),
  };
  return BlueZObexEvent(type, payload);
}

enum BlueZObexEventType {
  initialSnapshotComplete(0x00),
  session(0x01),
  transfer(0x02),
  phonebook(0x03),
  phonebookEntries(0x04),
  messageFolders(0x05),
  message(0x06),
  messageAccess(0x07),
  transferResult(0x10),
  error(0x20),
  objectAdded(0x7D),
  objectRemoved(0x7E),
  streamDone(0xFF),
  unknown(-1);

  final int discriminator;

  const BlueZObexEventType(this.discriminator);

  static BlueZObexEventType fromDiscriminator(int value) {
    for (final type in values) {
      if (type.discriminator == value) {
        return type;
      }
    }
    return unknown;
  }
}

class BlueZObexEvent {
  final BlueZObexEventType type;
  final Object? payload;

  const BlueZObexEvent(this.type, this.payload);
}

void _checkResult(String operation, int code, {required bool allowZero}) {
  if (code > 0 || allowZero && code == 0) {
    return;
  }
  throw nativeException(operation, code);
}

BlueZObexNativeException nativeException(String operation, int code) {
  if (code != -3) return BlueZObexNativeException(operation, code);
  final name = nativeBindings
      .bluez_obex_last_error_name()
      .cast<Utf8>()
      .toDartString();
  final message = nativeBindings
      .bluez_obex_last_error_message()
      .cast<Utf8>()
      .toDartString();
  return BlueZObexNativeException(
    operation,
    code,
    name: name.isEmpty ? null : name,
    message: message.isEmpty ? null : message,
  );
}
