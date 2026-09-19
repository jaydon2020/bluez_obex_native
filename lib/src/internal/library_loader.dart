/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'dart:ffi';
import 'dart:io';

const _fileName = 'libbluez_obex_native.so';

DynamicLibrary loadBluezObexNative() {
  final override = Platform.environment['BLUEZ_OBEX_LIB'];
  if (override != null && override.isNotEmpty) {
    return DynamicLibrary.open(override);
  }

  if (!Platform.isLinux) {
    if (Platform.isMacOS || Platform.isIOS) {
      return DynamicLibrary.open(
        'bluez_obex_native.framework/bluez_obex_native',
      );
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('bluez_obex_native.dll');
    }
    if (Platform.isAndroid) return DynamicLibrary.open(_fileName);
    throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
  }

  final errors = <String>[];
  try {
    return DynamicLibrary.open(_fileName);
  } catch (error) {
    errors.add('dlopen($_fileName): $error');
  }

  final loadedSibling = _findSiblingOfLoadedLibrary(_fileName);
  if (loadedSibling != null) {
    try {
      return DynamicLibrary.open(loadedSibling);
    } catch (error) {
      errors.add('$loadedSibling: $error');
    }
  }

  final candidates = <String>[];
  final hookArtifact = _findHookArtifact(_fileName);
  if (hookArtifact != null) candidates.add(hookArtifact);

  try {
    final scriptDir = File(Platform.script.toFilePath()).parent.path;
    candidates.addAll([
      '$scriptDir/lib/$_fileName',
      '$scriptDir/../lib/$_fileName',
      '$scriptDir/../../lib/$_fileName',
      '$scriptDir/../../../lib/$_fileName',
    ]);
  } catch (_) {}

  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final cwd = Directory.current.path;
  candidates.addAll([
    '$executableDir/$_fileName',
    '$executableDir/lib/$_fileName',
    '$cwd/lib/$_fileName',
    '$cwd/build/native/$_fileName',
    '$cwd/build-asan/$_fileName',
    '${Directory(cwd).parent.path}/build/native/$_fileName',
  ]);

  for (final directory in (Platform.environment['LD_LIBRARY_PATH'] ?? '').split(
    ':',
  )) {
    if (directory.isNotEmpty) candidates.add('$directory/$_fileName');
  }

  for (final path in candidates) {
    final file = File(path);
    if (!file.existsSync()) continue;
    try {
      return DynamicLibrary.open(file.absolute.path);
    } catch (error) {
      errors.add('${file.absolute.path}: $error');
    }
  }

  throw StateError(
    'Failed to load $_fileName. Searched:\n'
    '  dlopen($_fileName) via system loader\n'
    '${candidates.map((path) => '  $path (${File(path).existsSync() ? "exists" : "not found"})').join('\n')}\n'
    'Errors:\n${errors.join('\n')}\n'
    'Set BLUEZ_OBEX_LIB=/path/to/$_fileName to override.',
  );
}

String? _findHookArtifact(String fileName) {
  var directory = Directory.current;
  for (var i = 0; i < 6; i++) {
    final root = Directory(
      '${directory.path}/.dart_tool/hooks_runner/shared/'
      'bluez_obex_native/build',
    );
    if (root.existsSync()) {
      File? newest;
      var newestTime = DateTime.fromMillisecondsSinceEpoch(0);
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('/$fileName')) continue;
        final modified = entity.statSync().modified;
        if (modified.isAfter(newestTime)) {
          newest = entity;
          newestTime = modified;
        }
      }
      if (newest != null) return newest.path;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}

String? _findSiblingOfLoadedLibrary(String fileName) {
  try {
    final maps = File('/proc/self/maps');
    if (!maps.existsSync()) return null;

    final directories = <String>[];
    final seen = <String>{};
    for (final line in maps.readAsLinesSync()) {
      final path = line.substring(line.lastIndexOf(' ') + 1);
      if (!path.startsWith('/')) continue;
      final slash = path.lastIndexOf('/');
      if (slash <= 0) continue;
      final directory = path.substring(0, slash);
      if (seen.add(directory)) directories.add(directory);
    }

    for (final directory in directories) {
      final candidate = '$directory/$fileName';
      if (File(candidate).existsSync()) return candidate;
    }
  } catch (_) {}
  return null;
}
