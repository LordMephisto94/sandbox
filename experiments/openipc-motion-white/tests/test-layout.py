#!/usr/bin/env python3
"""Check the publication layout and source shell syntax without camera access."""
from pathlib import Path
import os
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
for name in ('build.sh', 'post-build.sh'):
    subprocess.run(['bash', '-n', str(root / name)], check=True)
scripts = sorted((root / 'files').glob('*.sh')) + [root / 'files/S96motion-white']
busybox = os.environ.get('BUSYBOX') or shutil.which('busybox')
if os.environ.get('STRICT') == '1' and not busybox:
    raise SystemExit('STRICT=1 requires BusyBox for target-shell parsing')
for script in scripts:
    command = [busybox, 'ash', '-n'] if busybox else ['sh', '-n']
    subprocess.run(command + [str(script)], check=True)
for file in root.rglob('*'):
    if not file.is_file() or 'build' in file.relative_to(root).parts:
        continue
    if file.suffix in {'.arm', '.ko', '.so', '.bin', '.tgz', '.tar'}:
        raise AssertionError(f'Generated or extracted binary in source tree: {file}')
print('Publication layout and shell syntax passed' + (' (BusyBox ash)' if busybox else ' (host sh; use STRICT=1 in CI)'))
