import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:bluez_obex_native/src/native_bridge.dart';
import 'package:test/test.dart';

void main() {
  test('reads a sized native payload and copies ownership to Dart', () {
    final result = readNativeBytes('fake_read', (out, capacity) {
      if (out == ffi.nullptr) return 3;
      out.asTypedList(capacity).setAll(0, [1, 2, 3]);
      return 3;
    });

    expect(result, Uint8List.fromList([1, 2, 3]));
  });

  test('turns native failures into typed exceptions', () {
    expect(
      () => readNativeBytes('fake_read', (_, _) => -3),
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
