#!/usr/bin/env python3
"""Run the real shell service against temporary fake camera interfaces."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parent.parent / "files"


def trial(apply, failure=False, exported=False):
    with tempfile.TemporaryDirectory(prefix="motion-white-test-") as directory:
        root = Path(directory)
        bindir = root / "bin"
        bindir.mkdir()
        (root / "value").write_text("0\n")
        (root / "active_low").write_text("0\n")
        (root / "night").write_text("1")
        (root / "monitor").write_text("true")
        (root / "count").write_text("0")
        (root / "actions").write_text("")
        (root / "helper-args").write_text("")
        if exported:
            (root / "gpio4").mkdir()
        for name in ("policy.sh", "motion-white.conf"):
            shutil.copy(SOURCE / name, root / name)
        (root / "motion-white.conf").write_text(
            "HOLD_SECONDS=2\nWHITE_HIGH_COUNT=22\nSETTLE_SECONDS=1\nIR_SETTLE_SECONDS=1\nAMBIENT_DELAY_SECONDS=1\nNIGHT_SENSOR_VALUE=0\n")
        script = (SOURCE / "service.sh").read_text()
        script = script.replace("/etc/motion-white.conf", str(root / "motion-white.conf"))
        script = script.replace("/etc/motion-white.restore", str(root / "journal"))
        script = script.replace("/tmp/motion-white.run", str(root / "run"))
        script = script.replace("/sys/class/gpio/gpio15/", str(root) + "/")
        script = script.replace("/sys/class/gpio/gpio4", str(root / "gpio4"))
        script = script.replace("/etc/init.d/S95majestic", str(bindir / "majestic-init"))
        (root / "motion-white.sh").write_text(script)
        stub = '''#!/usr/bin/env python3
import os,sys,signal
from pathlib import Path
r=Path(os.environ['MOCK_ROOT']); name=Path(sys.argv[0]).name; args=sys.argv[1:]
def record(s):
 with (r/'actions').open('a') as f:f.write(s+'\\n')
if name=='cli':
 if args[0]=='-g':
  values={'.motionDetect.enabled':'true','.nightMode.lightMonitor':(r/'monitor').read_text(),'.nightMode.irCutPin1':'8','.nightMode.irCutPin2':'9','.nightMode.backlightPin':'16','.nightMode.lightSensorPin':'15'}
  print(values[args[1]])
 else:
  if args[2]=='false': assert (r/'journal').read_text()=='true\\n'
  record('monitor '+args[2]);(r/'monitor').write_text(args[2])
elif name=='majestic-init':record('reload')
elif name=='curl':
 url=args[-1]
 if url.endswith('/metrics'):
  n=int((r/'count').read_text())+1;(r/'count').write_text(str(n))
  if n==10:os.kill(int((r/'run/pid').read_text()),signal.SIGTERM)
  if n==6 and os.environ.get('MOCK_FAILURE')=='1':sys.exit(22)
  print('night_enabled '+(r/'night').read_text())
  print('md_rects_acc_total '+str(100 if n<4 else 101))
 else:
  v='1' if url.endswith('/on') else '0';record('night '+v);(r/'night').write_text(v);print(v)
'''
        for name in ("cli", "curl", "majestic-init", "logger", "sync"):
            p = bindir / name
            p.write_text(stub)
            p.chmod(0o755)
        helper = root / "white-led-test.arm"
        helper.write_text('''#!/bin/sh
echo "$*" >> "$MOCK_ROOT/helper-args"
case "$*" in
 *lease*) echo white-on >> "$MOCK_ROOT/actions"; echo READY; trap 'echo white-off >> "$MOCK_ROOT/actions"; exit' TERM HUP INT; while read -r beat; do :; done;;
 *) echo white-off >> "$MOCK_ROOT/actions";;
esac
''')
        helper.chmod(0o755)
        env = dict(os.environ, MOCK_ROOT=str(root), MOCK_FAILURE=str(int(failure)),
                   PATH=str(bindir) + os.pathsep + os.environ["PATH"])
        result = subprocess.run(["sh", str(root / "motion-white.sh"),
                                 "--apply" if apply else "--dry-run"],
                                env=env, capture_output=True, text=True, timeout=30)
        actions = (root / "actions").read_text().splitlines()
        assert result.returncode in (1, 143), (result.returncode, result.stdout, result.stderr)
        if apply:
            helper_args = (root / "helper-args").read_text().splitlines()
            assert helper_args and all(("--reuse-gpio4" in a) == exported for a in helper_args), helper_args
            assert any('--high-count 22 lease' in a for a in helper_args), helper_args
            assert "white-on" in actions, (actions, result.stdout, result.stderr)
            assert actions.index("night 0") < actions.index("white-on"), actions
            after = actions[actions.index("white-on") + 1:]
            assert after.index("white-off") < after.index("night 1"), actions
            assert (root / "monitor").read_text() == "true", actions
            assert actions.count("monitor false") == 1 and actions.count("monitor true") == 1
        else:
            assert actions == [], actions
            assert "action=white" in result.stdout and "action=restore" in result.stdout, result.stdout
        assert not (root / "run").exists()
        assert not (root / "journal").exists()
        print(f"Service trial passed: apply={apply}, telemetry_failure={failure}, exported={exported}")


if __name__ == "__main__":
    trial(False)
    trial(True)
    trial(True, True)
    trial(True, exported=True)
