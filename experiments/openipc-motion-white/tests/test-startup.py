#!/usr/bin/env python3
"""The controller must wait for valid telemetry, and stop promptly while waiting."""
from pathlib import Path
import os
import subprocess
import tempfile
import time

source = Path(__file__).resolve().parent.parent / 'files/supervisor.sh'


def wait_for(predicate):
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(.05)
    raise AssertionError('Timed out')


for cancel in (False, True):
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        base = root / 'lib'
        base.mkdir()
        bindir = root / 'bin'
        bindir.mkdir()
        (root / 'conf').write_text('ENABLED=true\n')
        script = source.read_text()
        for old, new in [('/usr/libexec/motion-white', base),
                         ('/tmp/motion-white.supervisor', root / 'lock'),
                         ('/tmp/motion-white.run', root / 'run'),
                         ('/etc/motion-white.conf', root / 'conf'),
                         ('/sys/class/gpio/gpio15/value', root / 'sensor')]:
            script = script.replace(old, str(new))
        (base / 'supervisor.sh').write_text(script)
        (base / 'recover.sh').write_text('#!/bin/sh\nexit 0\n')
        (base / 'service.sh').write_text('''#!/bin/sh
touch "$TEST_ROOT/started"
trap 'exit 0' TERM
while :; do sleep 1 & wait $!; done
''')
        for name, body in {
            'logger': 'echo "$*" >> "$TEST_ROOT/log"',
            'curl': 'touch "$TEST_ROOT/polled"; cat "$TEST_ROOT/metrics"',
        }.items():
            p = bindir / name
            p.write_text('#!/bin/sh\n' + body + '\n')
            p.chmod(0o755)
        env = dict(os.environ, TEST_ROOT=str(root),
                   PATH=str(bindir) + ':' + os.environ['PATH'])
        proc = subprocess.Popen(['sh', str(base / 'supervisor.sh')], env=env,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            wait_for(lambda: (root / 'log').exists())
            assert not (root / 'started').exists()
            if not cancel:
                (root / 'sensor').write_text('1\n')
                (root / 'metrics').write_text('night_enabled 1\nmd_rects_acc_total invalid\n')
                wait_for(lambda: (root / 'polled').exists())
                assert not (root / 'started').exists()
                (root / 'metrics').write_text('night_enabled 1\nmd_rects_acc_total 0\n')
                wait_for(lambda: (root / 'started').exists())
            proc.terminate()
            proc.wait(timeout=4)
            assert not (root / 'lock').exists()
            assert 'Controller exited' not in (root / 'log').read_text()
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
print('Startup waits for GPIO and valid metrics; TERM stops a waiting supervisor')
