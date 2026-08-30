// Native assets build hook for bluez_obex_native.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    if (Platform.environment.containsKey('SKIP_NATIVE_BUILD')) {
      stderr.writeln('SKIP_NATIVE_BUILD set — skipping native build.');
      return;
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

    if (!File('${buildDir}CMakeCache.txt').existsSync()) {
      await _run('cmake', [
        '-S',
        nativeRoot,
        '-B',
        buildDir,
        '-DCMAKE_BUILD_TYPE=Release',
        '-DBUILD_TESTING=OFF',
        '-DBLUEZ_HOOK_BUILD=ON',
        if (await _which('ninja')) ...['-G', 'Ninja'],
      ]);
    }

    await _run('cmake', ['--build', buildDir, '--parallel']);

    final library = File('${buildDir}libbluez_obex_native.so');
    if (!library.existsSync()) {
      throw StateError('libbluez_obex_native.so not found at ${library.path}');
    }

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/ffi/bluez_obex_native_asset.dart',
        linkMode: DynamicLoadingBundled(),
        file: library.uri,
      ),
    );

    for (final directory in ['src', 'include', 'generated']) {
      final dir = Directory('$nativeRoot/$directory');
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (const [
          '.cpp',
          '.cc',
          '.c',
          '.hpp',
          '.h',
        ].any(entity.path.endsWith)) {
          output.dependencies.add(entity.uri);
        }
      }
    }
    output.dependencies.add(Uri.file('$nativeRoot/CMakeLists.txt'));

    stderr.writeln('libbluez_obex_native built: ${library.path}');
  });
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
