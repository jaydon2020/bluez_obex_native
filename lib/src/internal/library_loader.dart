// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Joel Winarske <joel.winarske@gmail.com>

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../ffi/bluez_obex_native_asset.dart';

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

  // Resolve the VM-selected asset, never a library found in the working directory.
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
}
