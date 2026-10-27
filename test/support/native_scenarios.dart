/*
 * Copyright (c) 2026 Jian De Seak jiande2020@gmail.com. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
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
    } else if (args.single == 'map_navigation') {
      final access = client.messageAccess('/org/bluez/obex/client/navigation');
      await access.setFolder('/telecom/msg/inbox');
      for (var i = 0; i < 2; i++) {
        final messages = await access.listMessages('telecom/msg/inbox');
        check(
          messages.single.lastProperties?.subject == 'Navigated inbox',
          'Failed to list inbox after changing the working folder',
        );
      }
    } else if (args.single == 'lifecycle_signals') {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      events.clear();
      print('signals-ready');
      await stdin.first;
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final statuses = events
          .where((event) => event.payload is BlueZObexTransferProps)
          .map((event) => event.payload! as BlueZObexTransferProps)
          .where(
            (props) =>
                props.objectPath == '/org/bluez/obex/client/session0/transfer0',
          )
          .map((props) => props.status)
          .toList();
      check(
        statuses.join(',') == 'active,queued,complete',
        'Malformed, wrong-type, foreign, or stale signal escaped: $statuses',
      );
      check(
        events.where((e) => e.type == BlueZObexEventType.objectAdded).length ==
            1,
        'Duplicate interface addition escaped',
      );
      check(
        events
                .where((e) => e.type == BlueZObexEventType.objectRemoved)
                .length ==
            1,
        'Duplicate interface removal escaped',
      );
      check(
        !events.any((e) => e.type == BlueZObexEventType.error),
        'Malformed signal terminated the native stream',
      );
      await client.getManagedObjects();
    } else if (args.single == 'input_validation') {
      Future<void> rejected(Future<Object?> Function() call) async {
        try {
          await call();
        } on ArgumentError {
          return;
        }
        throw StateError('Invalid native argument was dispatched');
      }

      await rejected(
        () =>
            client.createSession('AA:BB:CC:DD:EE:FF', target: 'pbap\u0000map'),
      );
      await rejected(
        () => client
            .transfer('/org/bluez/obex/client/session0/transfer0\u0000suffix')
            .cancel(),
      );
      await rejected(
        () => client
            .phonebook('/org/bluez/obex/client/session0')
            .list(filters: {'SearchValue': 'Ada\u0000Grace'}),
      );
      final props = await client
          .transfer('/org/bluez/obex/client/session0/transfer0')
          .properties();
      check(
        props.status == 'active',
        'Invalid cancellation mutated the transfer',
      );
    } else if (args.single == 'mixed_close') {
      var completions = 0;
      Future<T> counted<T>(Future<T> future) => future.then((value) {
        completions++;
        return value;
      });

      final transfer = client.transfer(
        '/org/bluez/obex/client/session0/transfer0',
      );
      final operations = <Future<Object?>>[
        counted(
          client.session('/org/bluez/obex/client/session0').capabilities(),
        ),
        counted(client.phonebook('/org/bluez/obex/client/session0').getSize()),
        counted(
          client.messageAccess('/org/bluez/obex/client/session0').updateInbox(),
        ),
        counted(transfer.suspend()),
        counted(transfer.resume()),
      ];
      final close = client.dispose();
      final results = await Future.wait(operations);
      await close;
      check(
        results[0] == 'capabilities:1',
        'Session Future completed incorrectly',
      );
      check(results[1] == 42, 'PBAP Future completed incorrectly');
      check(
        completions == operations.length,
        'A pending Future completed more than once',
      );
    } else {
      throw ArgumentError('Unknown scenario: ${args.single}');
    }
  } finally {
    await sub.cancel();
    await client.dispose();
  }
}
