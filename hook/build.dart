// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 Joel Winarske <joel.winarske@gmail.com>
// SPDX-FileCopyrightText: 2026 Jian De Seak

// Native assets build hook for bluez_obex_native.
//
// Builds libbluez_obex_native.so with CMake and exposes it as a bundled
// CodeAsset. Patterned after https://github.com/jwinarske/bluez_native,
// which is in turn patterned after
// https://github.com/meta-flutter/appstream_dart/blob/main/hook/build.dart.
// Both upstream projects are licensed under Apache-2.0; see
// LICENSES/Apache-2.0.txt.

import 'dart:io';
import 'dart:typed_data';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final skipNativeBuild = input.userDefines['skip_native_build'];
    if (skipNativeBuild is! bool?) {
      throw const FormatException(
        'hooks.user_defines.bluez_obex_native.skip_native_build must be a bool',
      );
    }
    if (skipNativeBuild == true ||
        Platform.environment.containsKey('SKIP_NATIVE_BUILD')) {
      stderr.writeln('Native build disabled — skipping CMake.');
      return;
    }

    final codeConfig = input.config.code;
    final toolchainUri = input.userDefines.path('cmake_toolchain_file');
    validateBuildTarget(
      OS.current,
      codeConfig.targetOS,
      Architecture.current,
      codeConfig.targetArchitecture,
      hasToolchain: toolchainUri != null,
    );

    if (toolchainUri != null) {
      final toolchain = File.fromUri(toolchainUri);
      if (!toolchain.existsSync()) {
        throw StateError('CMake toolchain file not found: ${toolchain.path}');
      }
      output.dependencies.add(toolchain.uri);
    }

    final packageRoot = input.packageRoot.toFilePath();
    final nativeRoot = '${packageRoot}native';
    final buildDir = input.outputDirectory.resolve('cmake/').toFilePath();
    await Directory(buildDir).create(recursive: true);

    final sdbus = File('$nativeRoot/third_party/sdbus-cpp/CMakeLists.txt');
    if (!sdbus.existsSync()) {
      if (!Directory('$packageRoot.git').existsSync() &&
          !File('$packageRoot.git').existsSync()) {
        throw StateError(
          'native/third_party/sdbus-cpp is missing and $packageRoot has no '
          '.git to restore it from. Clone with --recurse-submodules.',
        );
      }
      stderr.writeln('sdbus-cpp submodule missing; initializing');
      await _run('git', [
        '-C',
        packageRoot,
        'submodule',
        'update',
        '--init',
        '--recursive',
      ]);
    }

    await _run(
      'cmake',
      cmakeConfigureArguments(
        nativeRoot: nativeRoot,
        buildDirectory: buildDir,
        hostArchitecture: Architecture.current,
        targetArchitecture: codeConfig.targetArchitecture,
        toolchainUri: toolchainUri,
        hasNinja: await _which('ninja'),
      ),
    );

    await _run('cmake', ['--build', buildDir, '--parallel']);

    final library = File('${buildDir}libbluez_obex_native.so');
    if (!library.existsSync()) {
      throw StateError('libbluez_obex_native.so not found at ${library.path}');
    }
    final file = await library.open();
    try {
      validateElfHeader(await file.read(64), codeConfig.targetArchitecture);
    } finally {
      await file.close();
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/ffi/bluez_obex_native_asset.dart',
        linkMode: DynamicLoadingBundled(),
        file: library.uri,
      ),
    );

    output.dependencies.addAll(nativeDependencies(Directory(nativeRoot)));

    stderr.writeln('libbluez_obex_native built: ${library.path}');
  });
}

void validateElfHeader(Uint8List header, Architecture architecture) {
  final (elfClass, machine) = switch (architecture) {
    Architecture.arm => (1, 40),
    Architecture.arm64 => (2, 183),
    Architecture.ia32 => (1, 3),
    Architecture.x64 => (2, 62),
    Architecture.riscv32 => (1, 243),
    Architecture.riscv64 => (2, 243),
    _ => throw UnsupportedError(
      'Unsupported Linux architecture: $architecture',
    ),
  };
  if (header.length < 52 ||
      header[0] != 0x7f ||
      header[1] != 0x45 ||
      header[2] != 0x4c ||
      header[3] != 0x46 ||
      header[4] != elfClass ||
      header[5] != 1 ||
      header[6] != 1 ||
      (elfClass == 2 && header.length < 64)) {
    throw StateError(
      'Native library is not a valid little-endian $architecture ELF',
    );
  }
  final data = ByteData.sublistView(header);
  if (data.getUint16(16, Endian.little) != 3 ||
      data.getUint16(18, Endian.little) != machine) {
    throw StateError('Native library does not match Linux $architecture');
  }
}

Future<void> _run(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      'exit code $exitCode',
      exitCode,
    );
  }
}

Future<bool> _which(String executable) async {
  final result = await Process.run('which', [executable]);
  return result.exitCode == 0;
}

void validateBuildTarget(
  OS hostOS,
  OS targetOS,
  Architecture hostArchitecture,
  Architecture targetArchitecture, {
  required bool hasToolchain,
}) {
  if (hostOS != OS.linux || targetOS != OS.linux) {
    throw UnsupportedError(
      'bluez_obex_native requires a Linux host and target.',
    );
  }
  if (hostArchitecture != targetArchitecture && !hasToolchain) {
    throw UnsupportedError(
      'Cross-compiling bluez_obex_native from $hostArchitecture to '
      '$targetArchitecture requires '
      'hooks.user_defines.bluez_obex_native.cmake_toolchain_file.',
    );
  }
}

List<String> cmakeConfigureArguments({
  required String nativeRoot,
  required String buildDirectory,
  required Architecture hostArchitecture,
  required Architecture targetArchitecture,
  required Uri? toolchainUri,
  required bool hasNinja,
}) => [
  '-S',
  nativeRoot,
  '-B',
  buildDirectory,
  '-DCMAKE_BUILD_TYPE=Release',
  '-DBUILD_TESTING=OFF',
  '-DBLUEZ_HOOK_BUILD=ON',
  if (toolchainUri != null)
    '-DCMAKE_TOOLCHAIN_FILE=${File.fromUri(toolchainUri).path}',
  if (hostArchitecture != targetArchitecture)
    '-DBLUEZ_REQUIRE_CROSS_COMPILE=ON',
  if (hasNinja) ...['-G', 'Ninja'],
];

Iterable<Uri> nativeDependencies(Directory nativeRoot) sync* {
  yield nativeRoot.uri.resolve('CMakeLists.txt');
  yield nativeRoot.uri.resolve('exports.map');
  for (final name in [
    'src',
    'include',
    'generated',
    'third_party/sdbus-cpp/src',
    'third_party/sdbus-cpp/include',
  ]) {
    final directory = Directory.fromUri(nativeRoot.uri.resolve('$name/'));
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          (entity.path.endsWith('/CMakeLists.txt') ||
              [
                '.cpp',
                '.cc',
                '.c',
                '.hpp',
                '.h',
                '.cmake',
                '.in',
                '.inl',
              ].any(entity.path.endsWith))) {
        yield entity.uri;
      }
    }
  }
  yield nativeRoot.uri.resolve('third_party/sdbus-cpp/CMakeLists.txt');
}
