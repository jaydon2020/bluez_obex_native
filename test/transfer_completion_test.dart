/*
 * Copyright (c) 2026 Jian De Seak jiande2020@gmail.com. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:async';

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:test/test.dart';

import 'package:bluez_obex_native/src/internal/transfer_completion.dart';

void main() {
  const path = '/org/bluez/obex/client/session0/transfer0';
  const result = BlueZObexTransferResult(transferPath: path);

  late StreamController<BlueZObexEvent> events;
  late TransferCompletion completion;
  setUp(() {
    events = StreamController<BlueZObexEvent>.broadcast(sync: true);
    completion = TransferCompletion(events.stream);
  });
  tearDown(() async {
    await completion.close();
    await events.close();
  });

  void status(String value) => events.add(
    BlueZObexEvent(
      BlueZObexEventType.transfer,
      BlueZObexTransferProps(objectPath: path, status: value),
    ),
  );

  void removed() => events.add(
    const BlueZObexEvent(
      BlueZObexEventType.objectRemoved,
      BlueZObexObjectRemoved(
        objectPath: path,
        interfaceName: 'org.bluez.obex.Transfer1',
      ),
    ),
  );

  test('preserves completion received before the start reply', () async {
    expect(
      await completion.wait(() async {
        status('complete');
        removed();
        return result;
      }),
      same(result),
    );
  });

  test('removal without completion is failure', () async {
    await expectLater(
      completion.wait(() async {
        removed();
        return result;
      }),
      throwsStateError,
    );
  });

  test('failed transfer is never treated as successful removal', () async {
    await expectLater(
      completion.wait(() async {
        status('error');
        removed();
        return result;
      }),
      throwsStateError,
    );
  });

  test('waits for an asynchronous successful terminal status', () async {
    var finished = false;
    final future = completion.wait(() async => result).then((value) {
      finished = true;
      return value;
    });
    await Future<void>.delayed(Duration.zero);
    status('active');
    expect(finished, isFalse);
    status('complete');
    expect(await future, same(result));
  });

  test('stream closure and explicit abort fail unfinished transfers', () async {
    final future = completion.wait(() async => result);
    final assertion = expectLater(future, throwsStateError);
    await events.close();
    await assertion;

    await completion.close();
    events = StreamController<BlueZObexEvent>.broadcast();
    completion = TransferCompletion(events.stream);
    final aborted = completion.wait(() async => result);
    final abortAssertion = expectLater(aborted, throwsStateError);
    await completion.abort();
    await abortAssertion;
  });
}
