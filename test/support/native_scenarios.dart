/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:async';
import 'dart:io';
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
    if (args.single == 'disconnect' || args.single == 'restart') {
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
      if (args.single == 'restart') {
        try {
          await client.getManagedObjects();
          throw StateError('Used stale client after service restart');
        } on BlueZObexNativeException {
          /* expected */
        }
        await stdin.first;
        final replacement = await BlueZObexClient.connect();
        await replacement.getManagedObjects();
        await replacement.dispose();
      }
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
    } else if (args.single == 'default_target') {
      await client.createSession('AA:BB:CC:DD:EE:FF');
      try {
        await client.createSession('AA:BB:CC:DD:EE:FF', target: '');
        throw StateError('Accepted empty target');
      } on ArgumentError {
        /* expected */
      }
    } else if (args.single == 'responsive') {
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 10),
        (_) => ticks++,
      );
      try {
        final capabilities = await client
            .session('/org/bluez/obex/client/session0')
            .capabilities();
        check(
          capabilities == 'capabilities:1',
          'Remote operation executed more than once',
        );
        check(ticks >= 5, 'Native call blocked Dart timers');
      } finally {
        timer.cancel();
      }
      await Future.wait([client.dispose(), client.dispose()]);
      try {
        await client.getManagedObjects();
        throw StateError('Accepted call after disposal');
      } on StateError catch (error) {
        check(
          error.message.toString().contains('disposed'),
          'Unexpected disposal error',
        );
      }
    } else if (args.single == 'large_result') {
      final messages = await client
          .messageAccess('/org/bluez/obex/client/large')
          .listMessages('');
      check(
        messages.single.lastProperties!.subject.length == 1024 * 1024 + 1,
        'Large native result truncated',
      );
    } else if (args.single == 'folder_failure') {
      try {
        await client
            .messageAccess('/org/bluez/obex/client/large')
            .listMessages('missing/inbox');
        throw StateError('Returned messages despite failed navigation');
      } on BlueZObexNativeException catch (error) {
        check(
          error.name == 'org.bluez.obex.Error.Failed',
          'Missing D-Bus error name',
        );
        check(
          error.message == 'Folder unavailable',
          'Missing D-Bus error message',
        );
      }
    } else {
      throw ArgumentError('Unknown scenario: ${args.single}');
    }
  } finally {
    await sub.cancel();
    await client.dispose();
  }
}
