#!/usr/bin/env python3
from pathlib import Path
import os
import subprocess
import tempfile
src=Path(__file__).resolve().parent.parent/'files/recover.sh'
with tempfile.TemporaryDirectory() as d:
    p=Path(d); journal=p/'journal'; bindir=p/'bin'; bindir.mkdir()
    script=p/'recover.sh'
    script.write_text(src.read_text().replace('/etc/motion-white.restore',str(journal)).replace('/etc/init.d/S95majestic',str(bindir/'reload')))
    for name in ['cli','reload','sync']:
        f=bindir/name
        f.write_text('#!/bin/sh\n[ "${FAIL:-}" != "'+name+'" ]\n')
        f.chmod(0o755)
    env=dict(os.environ,PATH=str(bindir)+':'+os.environ['PATH'])
    for failing in ['cli','reload']:
        journal.write_text('true\n')
        assert subprocess.run(['sh',str(script)],env=dict(env,FAIL=failing)).returncode!=0
        assert journal.exists(), 'Failed recovery must retain journal'
    assert subprocess.run(['sh',str(script)],env=env).returncode==0
    assert not journal.exists()
    assert subprocess.run(['sh',str(script)],env=dict(env,FAIL='cli')).returncode==0
print('Recovery: failed writes/reload retain journal; successful recovery removes it; no journal is a no-op')
