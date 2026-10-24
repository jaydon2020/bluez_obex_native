#!/usr/bin/env python3
"""Build the actual pub archive offline and smoke-test a relocated native bundle."""

import os
from pathlib import Path
import re
import selectors
import shutil
import subprocess
import sys
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parent.parent
DART = os.environ.get("DART_EXECUTABLE", "dart")


def run(arguments, cwd, **kwargs):
    result = subprocess.run(
        arguments, cwd=cwd, capture_output=True, text=True, timeout=300, **kwargs
    )
    if result.returncode:
        raise RuntimeError(f"{arguments}:\n{result.stdout}\n{result.stderr}")
    return result.stdout


def ready(process):
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        if not selector.select(15):
            raise RuntimeError("Private bus/service readiness timed out")
        return process.stdout.readline().strip()


def main():
    run([DART, "pub", "publish", "--dry-run"], ROOT)
    with tempfile.TemporaryDirectory(prefix="bluez-obex-package-") as temporary:
        workspace = Path(temporary)
        archive = workspace / "package.tar.gz"
        # --to-archive writes pub's exact upload payload without uploading it.
        run([DART, "pub", "publish", f"--to-archive={archive}"], ROOT)
        package = workspace / "package"
        package.mkdir()
        with tarfile.open(archive) as payload:
            for member in payload.getmembers():
                path = Path(member.name)
                if path.is_absolute() or ".." in path.parts or member.issym() or member.islnk():
                    raise RuntimeError(f"Unsafe archive entry: {member.name}")
                if any(
                    part.startswith(".") or part == "build" or part.startswith("build-")
                    or part == "__pycache__" or part in ("ARCHITECTURE.md", "task.md")
                    for part in path.parts
                ) or path.suffix in (".pyc", ".o", ".a", ".so"):
                    raise RuntimeError(f"Development file in archive: {member.name}")
            payload.extractall(package, filter="data")
        for required in (
            "native/third_party/sdbus-cpp/CMakeLists.txt",
            "native/third_party/sdbus-cpp/COPYING",
            "native/third_party/sdbus-cpp/COPYING-LGPL-Exception",
            "LICENSES/Apache-2.0.txt", "doc/api.md", "doc/verification.md",
        ):
            if not (package / required).is_file():
                raise RuntimeError(f"Missing release file: {required}")

        consumer = workspace / "consumer"
        (consumer / "bin").mkdir(parents=True)
        (consumer / "pubspec.yaml").write_text(
            "name: obex_package_smoke\nenvironment:\n  sdk: ^3.10.0\n"
            "dependencies:\n  bluez_obex_native:\n    path: ../package\n"
        )
        (consumer / "bin/smoke.dart").write_text("""
import 'package:bluez_obex_native/bluez_obex_native.dart';
Future<void> main() async {
  final client = await BlueZObexClient.connect();
  try {
    final objects = await client.getManagedObjects();
    if (objects.transfers.length != 1) throw StateError('Missing native snapshot');
  } finally {
    await client.dispose();
  }
  print('OBEX package smoke passed');
}
""")
        run([DART, "pub", "get", "--offline"], consumer)
        # With no .git and an offline dependency resolution, this build must use
        # the dependency sources included in the archive.
        run([DART, "build", "cli", "--target", "bin/smoke.dart", "--output", "out"], consumer)
        relocated = workspace / "relocated"
        shutil.copytree(consumer / "out/bundle", relocated)
        library = relocated / "lib/libbluez_obex_native.so"
        expected = set(re.findall(r"\b(bluez_obex_\w+)\s*\(",
                                 (package / "native/include/bluez_obex_native.h").read_text()))
        actual = {line.split()[-1] for line in run(
            ["nm", "-D", "--defined-only", str(library)], workspace
        ).splitlines()}
        if actual != expected:
            raise RuntimeError(f"Unexpected ABI exports: extra={actual - expected}, missing={expected - actual}")

        untrusted = workspace / "untrusted"
        decoy = untrusted / ".dart_tool/hooks_runner/shared/bluez_obex_native/build/decoy/cmake"
        decoy.mkdir(parents=True)
        source = workspace / "decoy.c"
        source.write_text("#include <unistd.h>\n__attribute__((constructor)) static void decoy(void) { _exit(89); }\n")
        run(["cc", "-shared", "-fPIC", str(source), "-o", str(decoy / library.name)], workspace)
        processes = []
        try:
            bus = subprocess.Popen(
                ["dbus-daemon", "--session", "--nofork", "--print-address=1"],
                stdout=subprocess.PIPE, text=True,
            )
            processes.append(bus)
            env = dict(os.environ, DBUS_SESSION_BUS_ADDRESS=ready(bus))
            env.pop("BLUEZ_OBEX_LIB", None)
            env.pop("LD_LIBRARY_PATH", None)
            service = subprocess.Popen(
                [sys.executable, str(ROOT / "test/support/fake_obex.py")],
                env=env, stdout=subprocess.PIPE, text=True,
            )
            processes.append(service)
            if ready(service) != "ready":
                raise RuntimeError("Private service failed to start")
            output = run([str(relocated / "bin/smoke")], untrusted, env=env)
            if output.strip() != "OBEX package smoke passed":
                raise RuntimeError(output)
        finally:
            for process in reversed(processes):
                if process.poll() is None:
                    process.terminate()
                process.wait(timeout=5)
        print(f"Verified {archive.stat().st_size} byte archive, offline build, ABI exports and safe relocated loading")


if __name__ == "__main__":
    main()
