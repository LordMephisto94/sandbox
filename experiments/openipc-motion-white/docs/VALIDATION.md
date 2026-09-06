# Build and test results — 2026-09-06

Original camera-tested build: `output/images/openipc.hiseeu-g5clq-motion-white.tgz`

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

At the publication cleanup, the C helper and runtime files in `files/` were
unchanged from the firmware I tested. The build wrapper now takes a firmware-checkout path so it can run from
this repository. The cleanup also added the Makefile, CI and documentation.

`STRICT=1 make check` passed using the firmware's ARM BusyBox ash through QEMU.
The post-build hook was also checked in a separate target directory with the
original toolchain and the usual comment-stripped S99rc.local input. The helper,
runtime scripts, configuration and both init scripts matched the tested image
byte-for-byte.

## Boot readiness fix

My boot log showed the controller starting before metrics and GPIO15 were ready,
then succeeding on its 15-second retry. The supervisor now waits for those
inputs before launching the controller. Tests cover missing GPIO, malformed
metrics, successful startup once ready and stopping while waiting. This change
still needs a reboot check on the camera; the earlier image's hardware result
does not cover it.

The rebuilt readiness-fix image fits the same partition sizes: kernel 1,824,240
bytes, rootfs 5,206,016 bytes (36 KiB spare). The packaged squashfs contains the
new readiness check. Its SHA-256 is
`a65de067282af0e54e0ddfd49e8950c5dd81228f08534a740da659b69737db45`.
It replaces the earlier archive at the output path above.

### Waiting for night mode to settle

The next boot log showed valid metrics at 16:04:43, but `night=0` while
`sensor15=1`. By the 16:04:59 retry, both indicated night. Startup now requires
the configured sensor polarity and Majestic's night state to agree across two
consecutive checks. A missing, invalid or disagreeing reading resets that wait.
The controller keeps its own final state check in case the light changes between
the readiness check and startup. This revision still needs a camera reboot test.

The stable-state revision also builds within the same partition sizes. Its
packaged supervisor includes the state-agreement check; archive SHA-256:
`b5cc11a4115bf9ee05eb1ee04368dfbb39d31f98ec40818aa3be0c293fc64890`. This is now the latest build at the output path above.
