/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

// ignore_for_file: avoid_print

import 'package:bluez_obex_native/bluez_obex_native.dart';

const String kDefaultAddress = 'AA:BB:CC:DD:EE:FF';

String optionValue(List<String> args, String name, {String? fallback}) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    if (fallback != null) {
      return fallback;
    }
    throw FormatException('Missing value for $name.');
  }
  return args[index + 1];
}

bool hasFlag(List<String> args, String name) => args.contains(name);

void printUsage(String usage, List<String> details) {
  print('Usage: $usage');
  if (details.isEmpty) {
    return;
  }
  print('');
  for (final detail in details) {
    print(detail);
  }
}

Future<BlueZObexClient> createClient() async {
  try {
    return await BlueZObexClient.connect();
  } catch (error) {
    throw StateError(
      '$error\n'
      'Make sure BlueZ OBEX is running and the native library is available.',
    );
  }
}
