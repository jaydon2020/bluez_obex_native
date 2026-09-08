import 'dart:async';
import 'package:bluez_obex_native/bluez_obex_native.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main(List<String> args) async {
  final client = await BlueZObexClient.connect();
  final events = <BlueZObexEvent>[];
  final done = Completer<void>();
  final sub = client.events.listen(events.add, onDone: done.complete);
  try {
    if (args.single == 'disconnect') {
      print('connected');
      await done.future.timeout(const Duration(seconds: 5));
      check(
        events.any((e) => e.type == BlueZObexEventType.error),
        'Missing disconnection error',
      );
      check(
        events.any((e) => e.type == BlueZObexEventType.streamDone),
        'Missing terminal event',
      );
    } else {
      throw ArgumentError('Unknown scenario: ${args.single}');
    }
  } finally {
    await sub.cancel();
    await client.dispose();
  }
}
