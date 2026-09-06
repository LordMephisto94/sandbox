# Persistent HiseeU build validation — 2026-09-06

Artifact: `output/images/openipc.hiseeu-g5clq-motion-white.tgz`

SHA-256: `dfd002371dbbfcca7e50dcd64c1bce0766508f30cf2f9be3d9d3f5b340891700`

Kernel: 1,824,240 / 2,097,152 bytes. Rootfs: 5,206,016 / 5,242,880 bytes (36 KiB spare).
The archive's two image MD5 checksums match. Inspected the actual squashfs:
service/helper/config, S96 startup and S99 upgrade hooks present; SC223A sensor
libraries and existing LLDP startup preserved. The compiled ARM helper executes
its default read-only mode under QEMU with this firmware's musl loader.

Passed: 25 C controller mock scenarios; shell policy/trace tests; four service
integration scenarios; recovery failure tests; supervisor crash/restart/stop test.
Persistent scripts parse under the actual ARM BusyBox ash via QEMU. Repository
load_hisilicon, excludes, CI matrix and workflow lint tests passed. Both strict
shell parsing and comment stripping checks passed using ARM BusyBox under QEMU
(134 shared scripts). `git diff --check` passed.

Two broader repository checks could not complete in this host environment:
`test_sysupgrade.sh` requires unavailable native dash, and `test_kconfig_graph.py`
requires unavailable Python kconfiglib. These are not claimed as passed.

After this build, the owner flashed the image and reported working operation
and persistence after reboot. Power-failure recovery and upgrade shutdown still
require separate camera testing. See [HARDWARE.md](HARDWARE.md) for the exact
user report and the distinction between reported operation and captured logs. Default fixed brightness remains
6/111; hold 30 seconds, IR settling 15 seconds. No audio configuration was changed.

## Publication cleanup

The C helper and runtime files in `files/` remain byte-for-byte identical to the
source used for the owner-tested firmware. The host build wrapper now accepts
an explicit firmware-checkout path, so no sandbox-relative path or private home
directory is assumed. Packaging, test entry points, CI and documentation were
added; no new camera behaviour is claimed from those changes.

Publication validation reran `make check` with `STRICT=1` and the actual ARM
BusyBox ash through QEMU. All scenarios passed. The portable post-build hook
was run against an isolated target using the original toolchain and standard
comment-stripped S99rc.local input. Its helper, runtime scripts, configuration
and both init scripts matched the tested image byte-for-byte. The difference
in the host wrapper therefore does not require a claim of new camera testing.
