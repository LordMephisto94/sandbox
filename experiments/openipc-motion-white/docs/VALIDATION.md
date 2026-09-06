# Build and test results — 2026-09-06

Artifact: `output/images/openipc.hiseeu-g5clq-motion-white.tgz`

SHA-256: `dfd002371dbbfcca7e50dcd64c1bce0766508f30cf2f9be3d9d3f5b340891700`

Kernel: 1,824,240 / 2,097,152 bytes. Rootfs: 5,206,016 / 5,242,880 bytes (36 KiB spare).
Both image MD5 checksums in the archive match. The squashfs contains the helper,
service, configuration, S96 startup and S99 upgrade hooks. The SC223A sensor
libraries and my existing LLDP startup are still present. The compiled ARM
helper runs in its default read-only mode under QEMU with the firmware's musl
loader.

Passed: 25 C controller mock scenarios; shell policy/trace tests; four service
integration scenarios; recovery failure tests; supervisor crash/restart/stop test.
Persistent scripts parse under the actual ARM BusyBox ash via QEMU. Repository
load_hisilicon, excludes, CI matrix and workflow lint tests passed. Both strict
shell parsing and comment stripping checks passed using ARM BusyBox under QEMU
(134 shared scripts). `git diff --check` passed.

Two repository checks couldn't run because dependencies were missing:
`test_sysupgrade.sh` needs native dash, and `test_kconfig_graph.py` needs Python
kconfiglib.

I flashed this build onto my camera. The lighting works and stays working after
a reboot. I still need to test power-failure recovery and upgrade shutdown on the
camera. See [HARDWARE.md](HARDWARE.md) for the hardware notes and logs.

The defaults are brightness 6/111, a 30-second hold and 15 seconds of IR settling.
Audio configuration is unchanged.

## Repository cleanup

The C helper and runtime files in `files/` are unchanged from the firmware I
tested. The build wrapper now takes a firmware-checkout path so it can run from
this repository. The cleanup also added the Makefile, CI and documentation.

`STRICT=1 make check` passed using the firmware's ARM BusyBox ash through QEMU.
The post-build hook was also checked in a separate target directory with the
original toolchain and the usual comment-stripped S99rc.local input. The helper,
runtime scripts, configuration and both init scripts matched the tested image
byte-for-byte.
