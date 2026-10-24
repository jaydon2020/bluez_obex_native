/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:bluez_obex_native/src/native_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('rejects NUL in native arguments and filter keys/values', () {
    expect(() => NativeString('pbap\u0000map'), throwsArgumentError);
    for (final map in <Map<String, Object?>>[
      {'Read\u0000Deleted': true},
      {'SearchValue': 'Ada\u0000Grace'},
      {
        'Fields': ['FN', 'TEL\u0000EMAIL'],
      },
    ]) {
      expect(() => NativeStringMap(map), throwsArgumentError);
    }
    final values = NativeStringMap({
      'Read': true,
      'Fields': ['FN', 'TEL'],
    });
    try {
      expect(values.values[0].cast<Utf8>().toDartString(), 'true');
      expect(values.values[1].cast<Utf8>().toDartString(), 'FN,TEL');
    } finally {
      values.dispose();
    }
  });
  test('reads a sized native payload and copies ownership to Dart', () {
    var calls = 0;
    final result = readNativeBytes('fake_read', (out) {
      calls++;
      out.value = calloc<ffi.Uint8>(3);
      out.value.asTypedList(3).setAll(0, [1, 2, 3]);
      return 3;
    });

    expect(result, Uint8List.fromList([1, 2, 3]));
    expect(calls, 1);
  });

  test('turns native failures into typed exceptions', () {
    expect(
      () => readNativeBytes('fake_read', (_) => -3),
      throwsA(
        isA<BlueZObexNativeException>()
            .having((error) => error.operation, 'operation', 'fake_read')
            .having((error) => error.code, 'code', -3),
      ),
    );
  });

  test('bridge disposal is idempotent for a never-issued token', () {
    final bridge = BlueZObexNativeBridge(
      ffi.Pointer<ffi.Void>.fromAddress(0xdeadbeef),
    );

    bridge.dispose();
    bridge.dispose();
  });
}
