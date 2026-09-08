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
    } else if (args.single == 'completion') {
      final removed = client.events.firstWhere(
        (e) => e.type == BlueZObexEventType.objectRemoved,
      );
      await client
          .transfer('/org/bluez/obex/client/session0/transfer0')
          .cancel();
      await removed.timeout(const Duration(seconds: 5));
      final transfers = events
          .where((e) => e.payload is BlueZObexTransferProps)
          .map((e) => e.payload as BlueZObexTransferProps)
          .toList();
      check(
        transfers.any(
          (p) =>
              p.status == 'complete' &&
              p.session == '/org/bluez/obex/client/session0',
        ),
        'Lost completion or unchanged cached properties',
      );
    } else if (args.single == 'ownership') {
      final session = await client.createSession(
        'AA:BB:CC:DD:EE:FF',
        target: 'pbap',
      );
      check(
        session.objectPath == '/org/bluez/obex/client/session0',
        'Borrowed another connections session',
      );
    } else {
      throw ArgumentError('Unknown scenario: ${args.single}');
    }
  } finally {
    await sub.cancel();
    await client.dispose();
  }
}
