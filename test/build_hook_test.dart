/*
 * Copyright (c) 2026 Jian De Seak jiande2020@gmail.com. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import 'dart:io';
import 'package:test/test.dart';
import '../hook/build.dart' as hook;

void main() {
  test('CMake uses the compiler environment without a toolchain define', () {
    final arguments = hook.cmakeConfigureArguments(
      nativeRoot: '/source/native',
      buildDirectory: '/build/arm64',
      hasNinja: true,
    );
    expect(arguments, contains('-DBLUEZ_HOOK_BUILD=ON'));
    expect(arguments, isNot(contains(startsWith('-DCMAKE_TOOLCHAIN_FILE='))));
    expect(arguments, isNot(contains('-DBLUEZ_REQUIRE_CROSS_COMPILE=ON')));
    expect(arguments, containsAllInOrder(['-G', 'Ninja']));
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
