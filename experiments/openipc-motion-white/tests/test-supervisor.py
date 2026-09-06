#!/usr/bin/env python3
from pathlib import Path
import os, subprocess, tempfile, time
src=Path(__file__).resolve().parent.parent/'files'
with tempfile.TemporaryDirectory() as d:
    root=Path(d); base=root/'lib'; base.mkdir(); lock=root/'supervisor'; run=root/'run'; bin=root/'bin'; bin.mkdir()
    (root/'gpio15').write_text('1\n')
    (bin/'curl').write_text('#!/bin/sh\necho md_rects_acc_total 0\necho night_enabled 1\n'); (bin/'curl').chmod(0o755)
    conf=root/'config'; conf.write_text('ENABLED=true\n')
    (bin/'logger').write_text('#!/bin/sh\nexit 0\n'); (bin/'logger').chmod(0o755)
    supervisor=(src/'supervisor.sh').read_text().replace('/usr/libexec/motion-white',str(base)).replace('/tmp/motion-white.supervisor',str(lock)).replace('/tmp/motion-white.run',str(run)).replace('/etc/motion-white.conf',str(conf)).replace('sleep 15','sleep 1').replace('/sys/class/gpio/gpio15/value',str(root/'gpio15'))
    (base/'supervisor.sh').write_text(supervisor)
    (base/'recover.sh').write_text('#!/bin/sh\nif [ -f "'+str(root/'journal')+'" ]; then rm "'+str(root/'journal')+'"; echo recovered >> "'+str(root/'events')+'"; fi\n')
    (base/'service.sh').write_text('''#!/bin/sh
if [ ! -f "$TEST_ROOT/once" ]; then
 touch "$TEST_ROOT/once" "$TEST_ROOT/journal"
 exit 1
fi
echo running >> "$TEST_ROOT/events"
trap 'echo stopped >> "$TEST_ROOT/events"; exit 0' TERM
while :; do sleep 1 & wait $!; done
''')
    env=dict(os.environ,TEST_ROOT=str(root),PATH=str(bin)+':'+os.environ['PATH'])
    proc=subprocess.Popen(['sh',str(base/'supervisor.sh')],env=env)
    try:
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            if (root/'events').exists() and 'running' in (root/'events').read_text(): break
            time.sleep(.1)
        else: raise AssertionError('Supervisor did not restart child')
        proc.terminate(); proc.wait(timeout=5)
        assert (root/'events').read_text().splitlines()==['recovered','running','stopped']
        assert not lock.exists()
        assert not (root/'journal').exists()
    finally:
        if proc.poll() is None: proc.kill(); proc.wait()
print('Supervisor restarts failed controller, recovers journal and stops child on TERM')
