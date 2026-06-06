import 'dart:ffi';
import 'dart:io';

const String _libName = 'bluez_obex_native';

DynamicLibrary loadBluezObexNative() {
  final envPath = Platform.environment['BLUEZ_OBEX_LIB'];
  if (envPath != null && envPath.isNotEmpty) {
    return DynamicLibrary.open(envPath);
  }

  for (final path in _candidateLibraryPaths()) {
    if (File(path).existsSync()) {
      return DynamicLibrary.open(path);
    }
  }

  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}

List<String> _candidateLibraryPaths() {
  final executableDir = File(Platform.resolvedExecutable).parent.path;
  final cwd = Directory.current.path;

  if (Platform.isMacOS || Platform.isIOS) {
    return [
      '$executableDir/$_libName.framework/$_libName',
      '$cwd/build/native/$_libName.framework/$_libName',
    ];
  }
  if (Platform.isWindows) {
    return [
      '$executableDir/$_libName.dll',
      '$executableDir/bin/$_libName.dll',
      '$cwd/build/native/$_libName.dll',
    ];
  }

  return [
    '$executableDir/lib$_libName.so',
    '$executableDir/lib/lib$_libName.so',
    '$cwd/build/native/lib$_libName.so',
    '$cwd/build-asan/lib$_libName.so',
    '${Directory(cwd).parent.path}/build/native/lib$_libName.so',
  ];
}
