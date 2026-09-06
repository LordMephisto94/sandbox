# Motion-triggered white LEDs for HiseeU G5C-LQ/S38

At night, accepted motion switches the camera from IR illumination to colour
with fixed-brightness white LEDs. After 30 seconds without further accepted
motion, IR night mode returns. Boot startup and recovery are included.

The owner reports successful operation and persistence after reboot on a HiseeU
2 MP PTZ PoE camera: GK7205V200/V210 family, SC223A, 8 MiB SPI NOR. This is a
board-specific experiment, not a universal Goke PWM utility. See
[hardware and test evidence](docs/HARDWARE.md) for the scope of that report.

## Build

Dependencies: an OpenIPC firmware checkout and its normal Buildroot dependencies,
Bash, Python 3 and an ARM musl toolchain produced by that build. Tested against
firmware commit `2a0d5ca9a55a817fa6e9f62504425756fa9553ff` with existing local
LLDP/package changes; those changes are not included in this branch.

From this experiment's directory:

```sh
bash build.sh /path/to/openipc-firmware
```

An optional second argument chooses the Buildroot output directory. Paths must
not contain whitespace. Existing GK7205V200 lite output retains its configuration
and cached Majestic; a fresh output runs the firmware's usual defconfig setup.
The wrapper compiles the C helper from source and installs the runtime through a
post-build hook. It does not modify the firmware's shared source files.

The package is written to:

```
output/images/openipc.hiseeu-g5clq-motion-white.tgz
```

Both image partitions are checked in bytes: kernel at most 2 MiB, squashfs at
most 5 MiB. The tested image has only 36 KiB of rootfs headroom; other package
selections or upstream changes may exceed the cap. Use this wrapper for builds
that include the feature. A plain firmware `make` does not select this hook.

The C helper can also be compiled independently, without installing anything:

```sh
make CC=/path/to/arm-openipc-linux-musleabi-gcc
```

The default `make` uses the host compiler. `make check` always needs a native
compiler; use a separate invocation from cross-compilation.

## Camera configuration

`/etc/motion-white.conf` contains:

| Setting | Default | Meaning |
| --- | --- | --- |
| `ENABLED` | `true` | Start the controller at boot |
| `HOLD_SECONDS` | `30` | Time since the latest accepted motion |
| `WHITE_HIGH_COUNT` | `6` | PWM high count out of 111; accepted range 2–110 |
| `SETTLE_SECONDS` | `3` | Ignore transition motion after white turns on |
| `IR_SETTLE_SECONDS` | `15` | Ignore transition motion after returning to IR |
| `AMBIENT_DELAY_SECONDS` | `3` | Debounce ambient day/night changes |
| `NIGHT_SENSOR_VALUE` | `1` | Logical GPIO15 value observed at night |

Brightness is constant throughout each white-light event. PWM count is not a
perceived-brightness percentage. The owner tested a one-second pulse at 110;
that does not establish a continuous-operation thermal rating.

Restart after editing the configuration:

```sh
/etc/init.d/S96motion-white restart
```

Status and logs:

```sh
/etc/init.d/S96motion-white status
logread | grep motion-white
```

Status reports the supervisor process, not successful telemetry or illumination.
Startup failures are logged and retried. To disable, stop the service first and
set `ENABLED=false` in its configuration.

A previously configured camera should already have the required settings. On a
fresh, claimed camera, this optional one-time command applies the known GPIO
assignments, enables motion at sensitivity 1 and disables the image flip that
prevented motion detection on the tested sensor pipeline:

```sh
sh /usr/libexec/motion-white/configure.sh
```

It does not select the sensor driver or replace initial camera setup. The normal
OpenIPC password and Majestic EULA flow is retained. Only the human owner accepts
the EULA.

For a dry run, stop the active service first:

```sh
/etc/init.d/S96motion-white stop
sh /usr/libexec/motion-white/service.sh --dry-run
```

## Lifecycle and limitations

The service starts after Majestic. It journals and syncs the original automatic
light-monitor state before disabling it; cleanup, restart or reboot restores
that state. Failed recovery keeps the journal. The PWM worker independently
turns white off after four seconds without heartbeats. Configuration is not
written on every motion event. Logs use the existing bounded syslog.

The generated image adds S96 start/stop calls to S99rc.local, preserving its
original hooks. This connects shutdown and aborted-upgrade recovery to the
existing sysupgrade lifecycle. If S99rc.local is overridden in the writable
overlay, merge those calls into that override. The PWM driver and shared clock
remain those supplied by OpenIPC; PWM0 and audio are not changed.

Before upgrading from the old foreground trial, stop that trial with Ctrl-C.
Normal overlay-preserving upgrades retain configuration; a reset or
`sysupgrade -n` restores image defaults. Generic firmware does not contain this
experiment. Do not delete active `/tmp/motion-white.*` directories: those are
runtime locks and heartbeat state, not leftover installation files. The helper's
installed name `white-led-test.arm` is retained for compatibility with the
camera-tested service; the binary is generated during the build, not committed.

The ambient sensor is ignored while white is active to prevent feedback.
Motion during settling intervals is also ignored, including real movement.
This is motion detection, not person or presence detection. Daylight polarity,
crash/power-failure recovery on hardware, and upgrade-abort recovery require
separate verification; normal operation and reboot were reported working.

## Validation and publishing

```sh
make check
STRICT=1 make check
make clean
```

Strict mode requires BusyBox (`BUSYBOX=/path/to/busybox` can override discovery).
The workflow runs host tests and BusyBox syntax checks. It does not claim a full
firmware build or hardware test. See [validation](docs/VALIDATION.md),
[OpenIPC publication scope](docs/OPENIPC-COMPLIANCE.md) and the
[prepared PR description](PR-DRAFT.md).

License: [MIT](LICENSE), matching the sandbox repository. Only source, tests and
documentation are included; factory blobs and generated firmware are excluded.
