# Hardware and observed behaviour

## Scope

Owner-reported hardware: HiseeU 2 MP PTZ PoE, G5C-LQ/S38 board identification,
Goke GK7205V200/GK7205V210 family, SmartSens SC223A, 8 MiB SPI NOR. Two cameras
were reported as apparently identical, one stock and one OpenIPC. Board identity
is not proven by the SoC alone; compatibility with arbitrary GK7205V210 cameras
is not claimed.

| Function | Interface |
| --- | --- |
| IR-cut open / close | GPIO8 / GPIO9 |
| IR illumination | GPIO16 |
| Ambient light sensor | GPIO15, logical 1 observed at night |
| White illumination | PWM1 sharing the GPIO4 pad; GPIO4 low is off |

The helper uses the loaded OpenIPC `open_pwm` driver's `/dev/pwm` interface:
command 1, a 16-byte request (channel byte, padding, high count, total count,
enable byte, padding). It verifies register readback because ioctl success alone
was insufficient to establish the requested state.

PWM1 has total count 111. Control is 5 when enabled and 0 when disabled; the
helper checks the driver's additional count register is 10. It only changes the
GPIO4/PWM1 pad and PWM1 state. The pad is at `0x100c0010`; UART/I2C selections are
refused. The PWM block starts at `0x12080000`, with PWM1 at offset `0x20`.
Shared clock `0x120101bc` is checked against the observed `0x282`, never written.
PWM0 must remain untouched. Register access is MMIO configuration, not patching
vendor executable or module data memory.

## Owner-supplied evidence

The original OpenIPC snapshot included:

```
0x100c0010 0x00001000
0x120101bc 0x00000282
0x12080020 0x0000018f
0x12080024 0x000000c7
0x12080028 0x00000000
0x1208002c 0x00000000
```

Motion/hold dry-run excerpt after correcting night sensor polarity:

```
uptime=2966 counter=8301 night=1 sensor15=1 white=1 action=white
uptime=2981 counter=8867 night=1 sensor15=1 white=1 action=none
uptime=3011 counter=8867 night=1 sensor15=1 white=0 action=restore
```

This shows restoration 30 seconds after the last counter increase; it is a dry
run, not proof of hardware illumination. The owner subsequently reported that
live IR/white operation worked and that the IR settling delay prevented repeated
activation caused by exposure changes.

After flashing the persistent build, the owner's report was:

> It all works and remains persistant after a reboot nicely done

This is a direct user report from the development session, not an independently
captured boot log. No new post-reboot `dmesg`, `ipcinfo`, service status or video
artifact was supplied. Those must be obtained and redacted before presenting a
complete hardware-evidence bundle for an upstream device PR.

The tested image SHA-256 and build results are in [VALIDATION.md](VALIDATION.md).
Speaker hum remained a separate unresolved issue and is outside this feature.
No evidence is claimed for thermal endurance at high brightness, power removal
during a journal write, or compatibility with other board revisions.
