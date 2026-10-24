/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:async';

import 'package:bluez_obex_native/bluez_obex_native.dart';

/// Observe before starting: a transfer can finish before its method reply arrives.
class TransferCompletion {
  final _done = Completer<void>();
  final _statuses = <String, String>{};
  final _removed = <String>{};
  late final StreamSubscription<BlueZObexEvent> _subscription;
  String? _path;
  Object? _streamError;
  Object? _error;

  TransferCompletion(Stream<BlueZObexEvent> events) {
    _subscription = events.listen(
      (event) {
        final payload = event.payload;
        if (payload is BlueZObexTransferProps) {
          _statuses[payload.objectPath] = payload.status;
        } else if (payload is BlueZObexObjectAdded &&
            payload.interfaceName == 'org.bluez.obex.Transfer1') {
          _statuses.remove(payload.objectPath);
          _removed.remove(payload.objectPath);
        } else if (payload is BlueZObexObjectRemoved &&
            payload.interfaceName == 'org.bluez.obex.Transfer1') {
          _removed.add(payload.objectPath);
        }
        _settle();
      },
      onError: (Object error) {
        _streamError = error;
        _settle();
      },
      onDone: () {
        _streamError = StateError(
          'Event stream closed before transfer completion',
        );
        _settle();
      },
    );
  }

  Future<BlueZObexTransferResult> wait(
    Future<BlueZObexTransferResult> Function() start, {
    Duration timeout = const Duration(minutes: 2),
    void Function(BlueZObexTransferResult)? onStarted,
  }) async {
    final result = await start();
    _path = result.transferPath;
    for (final property in result.properties) {
      if (property.key == 'Status') {
        _statuses.putIfAbsent(_path!, () => property.value);
      }
    }
    onStarted?.call(result);
    _settle();
    await _done.future.timeout(timeout);
    if (_error case final error?) throw error;
    return result;
  }

  void _settle() {
    if (_done.isCompleted || _path == null) return;
    final status = _statuses[_path];
    if (status == 'complete') {
      _done.complete();
      return;
    }
    if (status == 'error' || status == 'failed' || status == 'cancelled') {
      _error = StateError('Transfer $status');
    } else if (_removed.contains(_path)) {
      _error = StateError('Transfer removed before confirmed completion');
    } else {
      _error = _streamError;
    }
    if (_error != null) _done.complete();
  }

  Future<void> abort() async {
    _streamError = StateError('Transfer listener closed');
    _settle();
    await close();
  }

  Future<void> close() => _subscription.cancel();
}

Future<BlueZObexTransferResult> waitForTransfer(
  BlueZObexClient client,
  Future<BlueZObexTransferResult> Function() start,
) async {
  final completion = TransferCompletion(client.events);
  try {
    return await completion.wait(start);
  } finally {
    await completion.close();
  }
}
