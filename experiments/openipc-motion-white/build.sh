#!/bin/bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 /path/to/openipc-firmware [/path/to/output]" >&2
    exit 2
fi
FW=$(cd -- "$1" && pwd)
[[ -f "$FW/general/openipc.fragment" && -f "$FW/Makefile" ]] || {
    echo 'Expected an OpenIPC firmware checkout' >&2; exit 1;
}
OUT=${2:-"$FW/output"}
OUT=$(realpath -m "$OUT")
# Buildroot's post-build hook list is whitespace-separated.
case "$HERE$FW$OUT" in *[[:space:]]*) echo 'Build paths must not contain whitespace' >&2; exit 1;; esac
cd "$FW"
export HOST_CFLAGS=${HOST_CFLAGS:--O2 -std=gnu17}
export CMAKE_POLICY_VERSION_MINIMUM=3.5
VERSION=$(awk '$1=="BR_VER" {print $3; exit}' Makefile)
if [[ -f "$OUT/.config" ]]; then
    grep -qx 'BR2_OPENIPC_SOC_MODEL="gk7205v200"' "$OUT/.config" || { echo 'Output belongs to a different board' >&2; exit 1; }
    grep -qx 'BR2_OPENIPC_VARIANT="lite"' "$OUT/.config" || exit 1
fi
# Reuse a configured build without refreshing the rolling Majestic download.
if [[ ! -f "$OUT/.config" || ! -d "$OUT/buildroot-$VERSION" ]]; then
    make BOARD=gk7205v200_lite TARGET="$OUT" defconfig
fi
make -C "$OUT/buildroot-$VERSION" O="$OUT" BR2_EXTERNAL="$FW/general" \
    BR2_ROOTFS_POST_BUILD_SCRIPT="$FW/general/scripts/rootfs_script.sh $HERE/post-build.sh" \
    all -j"$(nproc)"
# Check bytes exactly, before the normal OpenIPC repack renames the files.
python3 - "$OUT/images" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
for name,cap in [('uImage',2097152),('rootfs.squashfs',5242880)]:
    size=(p/name).stat().st_size
    print(f'{name}: {size} / {cap} bytes; headroom {cap-size}')
    if not 0<size<=cap: raise SystemExit(f'{name} exceeds 8 MiB NOR partition')
PY
make BOARD=gk7205v200_lite TARGET="$OUT" repack
cp "$OUT/images/openipc.gk7205v200-nor-lite.tgz" "$OUT/images/openipc.hiseeu-g5clq-motion-white.tgz"
sha256sum "$OUT/images/openipc.hiseeu-g5clq-motion-white.tgz"
