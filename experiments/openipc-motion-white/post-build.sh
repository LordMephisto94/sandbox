#!/bin/bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
TARGET_DIR=${1:?Buildroot target directory required}
: "${HOST_DIR:?}" "${BR2_EXTERNAL_GENERAL_PATH:?}"
DEST="$TARGET_DIR/usr/libexec/motion-white"
install -d "$DEST" "$TARGET_DIR/etc/init.d"
"$HOST_DIR/bin/arm-openipc-linux-musleabi-gcc" -D_GNU_SOURCE -Os -Wall -Wextra -Werror -std=c11 -s "$HERE/src/white-led.c" -o "$DEST/white-led-test.arm"
for name in service.sh policy.sh supervisor.sh recover.sh configure.sh; do
    awk -f "$BR2_EXTERNAL_GENERAL_PATH/scripts/strip-shell-comments.awk" "$HERE/files/$name" > "$DEST/$name"
    sh -n "$DEST/$name"
    chmod 755 "$DEST/$name"
done
install -m 644 "$HERE/files/motion-white.conf" "$TARGET_DIR/etc/motion-white.conf"
install -m 755 "$HERE/files/S96motion-white" "$TARGET_DIR/etc/init.d/S96motion-white"
# Device-local wrapper preserves rc.local hooks and is called by sysupgrade,
# including a self-updated sysupgrade. Standard overlay resets this each build.
python3 - "$TARGET_DIR/etc/init.d/S99rc.local" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
needle='start() {'
if s.count(needle)!=1 or s.count('stop() {')!=1:
    raise SystemExit('Unexpected S99rc.local layout: inspect upgrade integration')
s=s.replace(needle, needle+'\n\t/etc/init.d/S96motion-white start')
s=s.replace('stop() {','stop() {\n\t/etc/init.d/S96motion-white stop || return 1')
p.write_text(s)
PY
sh -n "$TARGET_DIR/etc/init.d/S99rc.local"
