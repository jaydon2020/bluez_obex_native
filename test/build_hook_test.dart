/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:test/test.dart';
import '../hook/build.dart' as hook;

void main() {
  test('accepts a Linux host and target', () {
    expect(
      () => hook.validateOperatingSystems(OS.linux, OS.linux),
      returnsNormally,
    );
  });

  test('rejects a non-Linux host or target', () {
    expect(
      () => hook.validateOperatingSystems(OS.windows, OS.linux),
      throwsUnsupportedError,
    );
    expect(
      () => hook.validateOperatingSystems(OS.linux, OS.windows),
      throwsUnsupportedError,
    );
  });

  test('tracks vendor sources and CMake inputs for hook invalidation', () {
    final dependencies = hook.nativeDependencies(Directory('native')).toSet();
    for (final path in [
      'native/third_party/sdbus-cpp/src/Connection.cpp',
      'native/third_party/sdbus-cpp/include/sdbus-c++/IConnection.h',
      'native/third_party/sdbus-cpp/include/sdbus-c++/ConvenienceApiClasses.inl',
      'native/third_party/sdbus-cpp/CMakeLists.txt',
    ]) {
      expect(dependencies, contains(File(path).uri));
    }
  });
}
