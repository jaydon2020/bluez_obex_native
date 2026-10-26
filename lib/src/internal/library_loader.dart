// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Joel Winarske <joel.winarske@gmail.com>
// SPDX-FileCopyrightText: 2026 Jian De

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../ffi/bluez_obex_native_asset.dart';

const _libraryName = 'libbluez_obex_native.so';

final class _DlInfo extends Struct {
  external Pointer<Utf8> filename;
  external Pointer<Void> base;
  external Pointer<Utf8> symbol;
  external Pointer<Void> address;
}

DynamicLibrary loadBluezObexNative() {
  if (!Platform.isLinux) {
    throw UnsupportedError('bluez_obex_native requires Linux');
  }
  final override = Platform.environment['BLUEZ_OBEX_LIB'];
  if (override != null && override.isNotEmpty) {
    return DynamicLibrary.open(override);
  }

  final errors = <String>[];
  try {
    return DynamicLibrary.open(_libraryName);
  } catch (error) {
    errors.add('dlopen($_libraryName): $error');
  }

  final sibling = findSiblingOfLoadedLibrary(_libraryName);
  if (sibling != null) {
    try {
      return DynamicLibrary.open(sibling);
    } catch (error) {
      errors.add('dlopen($sibling): $error');
    }
  }

  // Native Assets remains the fallback for Dart CLI and standard bundles.
  try {
    final dladdr = DynamicLibrary.open('libdl.so.2')
        .lookupFunction<
          Int32 Function(Pointer<Void>, Pointer<_DlInfo>),
          int Function(Pointer<Void>, Pointer<_DlInfo>)
        >('dladdr');
    final info = calloc<_DlInfo>();
    try {
      final anchor =
          Native.addressOf<NativeFunction<Void Function(Pointer<Void>)>>(
            bundledObexInit,
          );
      if (dladdr(anchor.cast(), info) == 0 || info.ref.filename == nullptr) {
        throw StateError('Cannot locate the bundled BlueZ OBEX native asset');
      }
      return DynamicLibrary.open(info.ref.filename.toDartString());
    } finally {
      calloc.free(info);
    }
  } catch (error) {
    errors.add('Native Asset resolution: $error');
  }

  final mappedSibling = findSiblingOfLoadedLibrary(
    _libraryName,
    flutterOnly: false,
  );
  if (mappedSibling != null) {
    try {
      return DynamicLibrary.open(mappedSibling);
    } catch (error) {
      errors.add('dlopen($mappedSibling): $error');
    }
  }

  throw StateError(
    'Failed to load $_libraryName. Set BLUEZ_OBEX_LIB to its absolute path.\n'
    'Errors:\n${errors.join('\n')}',
  );
}

/// Finds [libraryName] beside a library already mapped into this process.
String? findSiblingOfLoadedLibrary(
  String libraryName, {
  String? maps,
  bool flutterOnly = true,
}) {
  if (!Platform.isLinux) return null;
  try {
    final contents = maps ?? File('/proc/self/maps').readAsStringSync();
    final seen = <String>{};
    final directories = <String>[];
    for (final line in contents.split('\n')) {
      final pathStart = line.indexOf('/');
      if (pathStart < 0) continue;
      var path = line.substring(pathStart).trim();
      if (path.endsWith(' (deleted)')) {
        path = path.substring(0, path.length - ' (deleted)'.length);
      }
      final slash = path.lastIndexOf('/');
      if (slash <= 0) continue;
      final directory = path.substring(0, slash);
      final basename = path.substring(slash + 1);
      if (!flutterOnly ||
          basename == 'libapp.so' ||
          basename.startsWith('libflutter_')) {
        if (!seen.add(directory)) continue;
        directories.add(directory);
      }
    }
    for (final directory in directories) {
      final candidate = '$directory/$libraryName';
      if (File(candidate).existsSync()) return candidate;
    }
  } on FileSystemException {
    return null;
  }
  return null;
}
