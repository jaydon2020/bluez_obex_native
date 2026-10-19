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
  test('accepts a native Linux build', () {
    expect(
      () => hook.validateBuildTarget(
        OS.linux,
        OS.linux,
        Architecture.x64,
        Architecture.x64,
        hasToolchain: false,
      ),
      returnsNormally,
    );
  });

  test('rejects a non-Linux host or target', () {
    expect(
      () => hook.validateBuildTarget(
        OS.windows,
        OS.linux,
        Architecture.x64,
        Architecture.x64,
        hasToolchain: false,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => hook.validateBuildTarget(
        OS.linux,
        OS.windows,
        Architecture.x64,
        Architecture.x64,
        hasToolchain: false,
      ),
      throwsUnsupportedError,
    );
  });

  test('cross-architecture builds require a toolchain', () {
    expect(
      () => hook.validateBuildTarget(
        OS.linux,
        OS.linux,
        Architecture.x64,
        Architecture.arm64,
        hasToolchain: false,
      ),
      throwsUnsupportedError,
    );
    expect(
      () => hook.validateBuildTarget(
        OS.linux,
        OS.linux,
        Architecture.x64,
        Architecture.arm64,
        hasToolchain: true,
      ),
      returnsNormally,
    );
  });

  test('cross-build CMake arguments use the supplied toolchain', () {
    final arguments = hook.cmakeConfigureArguments(
      nativeRoot: '/source/native',
      buildDirectory: '/build/arm64',
      hostArchitecture: Architecture.x64,
      targetArchitecture: Architecture.arm64,
      toolchainUri: Uri.file('/sdk/agl-toolchain.cmake'),
      hasNinja: true,
    );
    expect(
      arguments,
      contains('-DCMAKE_TOOLCHAIN_FILE=/sdk/agl-toolchain.cmake'),
    );
    expect(arguments, contains('-DBLUEZ_REQUIRE_CROSS_COMPILE=ON'));
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
