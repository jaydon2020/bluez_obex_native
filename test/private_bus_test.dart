/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:io';
import 'package:test/test.dart';

void main() {
  for (final scenario in [
    'disconnect',
    'completion',
    'ownership',
    'default_target',
    'responsive',
    'large_result',
    'folder_failure',
    'map_navigation',
    'lifecycle_signals',
    'input_validation',
    'mixed_close',
    'restart',
  ]) {
    test('native private bus: $scenario', () async {
      final dependencies = await Process.run('/usr/bin/python3', [
        '-c',
        'import dbus; from gi.repository import GLib',
      ]);
      if (dependencies.exitCode != 0) {
        if (Platform.environment['CI'] == 'true') {
          fail('CI requires python-dbus and PyGObject: ${dependencies.stderr}');
        }
        markTestSkipped('Requires python-dbus and PyGObject');
        return;
      }
      final result = await Process.run(
        '/usr/bin/python3',
        ['scripts/test_private_bus.py', scenario],
        environment: {'DART_EXECUTABLE': Platform.resolvedExecutable},
      );
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    }, skip: !Platform.isLinux);
  }
}
