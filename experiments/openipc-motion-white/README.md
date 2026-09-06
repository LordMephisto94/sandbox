# Motion-triggered white LEDs for HiseeU G5C-LQ/S38

At night, accepted motion switches the camera from IR illumination to colour
with fixed-brightness white LEDs. After 30 seconds without further accepted
motion, IR night mode returns. Boot startup and recovery are included.

I built this for my HiseeU 2 MP PTZ PoE camera: GK7205V200/V210 family,
SC223A, 8 MiB SPI NOR. I've tested the motion-triggered lighting and confirmed
that it still works after a reboot. The GPIO assignments are specific to this
board; see my [hardware notes](docs/HARDWARE.md) before trying another camera.

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
perceived-brightness percentage. I tried a one-second pulse at 110 and it was
very bright. I haven't tested it at that level for extended periods.

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

A previously configured camera should already have the required settings. After
completing setup on a fresh camera, this optional one-time command applies the
known GPIO assignments, enables motion at sensitivity 1 and disables the image
flip that prevented motion detection on my camera:

```sh
sh /usr/libexec/motion-white/configure.sh
```

Set up the sensor driver separately. You'll still need to complete OpenIPC's
normal password setup and accept the Majestic EULA yourself.

For a dry run, stop the active service first:

```sh
/etc/init.d/S96motion-white stop
sh /usr/libexec/motion-white/service.sh --dry-run
```

## Lifecycle and limitations

The service waits for valid motion/night metrics and GPIO15 before starting the
controller. It checks every two seconds, so a slow boot does not need a fixed
delay. A waiting message is logged initially and every 30 unsuccessful checks.
Once running, telemetry failures still stop the controller and trigger recovery.

It journals and syncs the original automatic
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
This detects movement rather than people or continued presence. I still need to
check daylight polarity, crash and power-failure recovery on the camera, and
recovery after an aborted upgrade. Normal operation and reboot persistence work
on my camera.

## Validation and publishing

```sh
make check
STRICT=1 make check
make clean
```

Strict mode requires BusyBox (`BUSYBOX=/path/to/busybox` can override discovery).
CI runs host tests and BusyBox syntax checks; firmware builds and camera tests
are separate. See the [test results](docs/VALIDATION.md),
[OpenIPC integration notes](docs/OPENIPC-COMPLIANCE.md) and
[PR description](PR-DRAFT.md).

License: [MIT](LICENSE), matching the sandbox repository. Only source, tests and
documentation are included; factory blobs and generated firmware are excluded.
