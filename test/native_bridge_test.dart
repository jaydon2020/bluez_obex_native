import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:bluez_obex_native/src/native_bridge.dart';
import 'package:test/test.dart';

void main() {
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
