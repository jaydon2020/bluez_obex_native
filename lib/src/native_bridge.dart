import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../bluez_obex_native_bindings_generated.dart';
import 'ffi/codec.dart';
import 'ffi/types.dart';

import 'internal/library_loader.dart';

final ffi.DynamicLibrary _dylib = loadBluezObexNative();

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

  const BlueZObexNativeException(this.operation, this.code);

  @override
  String toString() => 'BlueZObexNativeException($operation failed: $code)';
}

class BlueZObexNativeBridge {
  final ffi.Pointer<ffi.Void> handle;

  const BlueZObexNativeBridge(this.handle);

  Uint8List readBytes(
    String operation,
    int Function(ffi.Pointer<ffi.Uint8> out, int capacity) call,
  ) {
    return readNativeBytes(operation, call);
  }

  T readGlaze<T>(
    String operation,
    int Function(ffi.Pointer<ffi.Uint8> out, int capacity) call,
  ) {
    return GlazeCodec.decode<T>(readBytes(operation, call), 0);
  }

  String readUtf8(
    String operation,
    int Function(ffi.Pointer<ffi.Uint8> out, int capacity) call,
  ) {
    return utf8.decode(readBytes(operation, call));
  }

  void checkStatus(String operation, int code) {
    _checkResult(operation, code, allowZero: true);
  }

  void dispose() {
    nativeBindings.bluez_obex_client_destroy(handle);
  }
}

Uint8List readNativeBytes(
  String operation,
  int Function(ffi.Pointer<ffi.Uint8> out, int capacity) call,
) {
  final needed = call(ffi.nullptr, 0);
  _checkResult(operation, needed, allowZero: true);
  if (needed == 0) {
    return Uint8List(0);
  }

  final out = calloc<ffi.Uint8>(needed);
  try {
    final written = call(out, needed);
    _checkResult(operation, written, allowZero: true);
    return Uint8List.fromList(out.asTypedList(written));
  } finally {
    calloc.free(out);
  }
}

T readNativeGlaze<T>(
  String operation,
  int Function(ffi.Pointer<ffi.Uint8> out, int capacity) call,
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
    BlueZObexEventType.error => GlazeCodec.decode<BlueZObexError>(message, 1),
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
  transferResult(0x10),
  error(0x20),
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
  throw BlueZObexNativeException(operation, code);
}
