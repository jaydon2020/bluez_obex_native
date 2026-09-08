"""Exercise the real FFI backend on a private bus (python-dbus and PyGObject)."""
import os
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
scenario = sys.argv[1] if len(sys.argv) > 1 else 'disconnect'
bus = subprocess.Popen(['dbus-daemon', '--session', '--nofork', '--print-address=1'],
                       stdout=subprocess.PIPE, text=True)
service = child = None
try:
    address = bus.stdout.readline().strip()
    env = dict(os.environ, DBUS_SESSION_BUS_ADDRESS=address)
    service = subprocess.Popen([sys.executable, str(root / 'test/support/fake_obex.py')],
                               env=env, stdout=subprocess.PIPE, text=True)
    assert service.stdout.readline().strip() == 'ready'
    child = subprocess.Popen([
        os.environ.get('DART_EXECUTABLE', 'dart'),
        '--packages=' + str(root / '.dart_tool/package_config.json'),
        str(root / 'test/support/native_scenarios.dart'), scenario],
        cwd=root, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if scenario == 'disconnect':
        assert child.stdout.readline().strip() == 'connected'
        bus.terminate()
    out, err = child.communicate(timeout=20)
    print(out, end='')
    print(err, end='', file=sys.stderr)
    assert child.returncode == 0, f'{scenario}: exit {child.returncode}'
finally:
    for process in (child, service, bus):
        if process is not None:
            if process.poll() is None:
                process.terminate()
            process.wait(timeout=5)
