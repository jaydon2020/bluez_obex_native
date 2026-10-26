/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:io';

import 'package:bluez_obex_native/src/internal/library_loader.dart';
import 'package:test/test.dart';

void main() {
  test('finds the native library beside a mapped libapp.so', () async {
    final root = await Directory.systemTemp.createTemp('obex-loader-test.');
    addTearDown(() => root.delete(recursive: true));
    final libraries = await Directory(
      '${root.path}/release/lib',
    ).create(recursive: true);
    final library = await File(
      '${libraries.path}/libbluez_obex_native.so',
    ).create();

    final result = findSiblingOfLoadedLibrary(
      'libbluez_obex_native.so',
      maps:
          '7f000000-7f001000 r-xp 00000000 00:00 0 '
          '${libraries.path}/libapp.so\n',
    );

    expect(result, library.path);
  });

  test('ignores a native library beside an unrelated mapping', () async {
    final root = await Directory.systemTemp.createTemp('obex-loader-test.');
    addTearDown(() => root.delete(recursive: true));
    final library = await File('${root.path}/libbluez_obex_native.so').create();

    final result = findSiblingOfLoadedLibrary(
      library.uri.pathSegments.last,
      maps:
          '7f000000-7f001000 r-xp 00000000 00:00 0 '
          '${root.path}/libfixture.so\n',
    );

    expect(result, isNull);
  });
}
