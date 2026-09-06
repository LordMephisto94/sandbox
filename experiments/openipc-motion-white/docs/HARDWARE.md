# Hardware notes

## My cameras

I have two HiseeU 2 MP PTZ PoE cameras that appear to use the same hardware:
G5C-LQ/S38, Goke GK7205V200/GK7205V210 family, SmartSens SC223A and 8 MiB SPI NOR.
During development I kept one on stock firmware and used the other for OpenIPC.
I haven't confirmed compatibility with other board revisions or cameras that
happen to use the same SoC.

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

## Testing

My initial OpenIPC register snapshot included:

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

The dry run restores night mode 30 seconds after the last counter increase.
In the live test, IR and white lighting switched correctly. Adding the IR
settling delay stopped the exposure change from immediately triggering the
white LEDs again.

I flashed the persistent build and confirmed that the lighting works and starts
automatically after reboot. I haven't added post-reboot `dmesg`, `ipcinfo`,
service status or video captures here yet. I'll need those for an upstream
device PR, with any private details removed.

The image checksum and build results are in [VALIDATION.md](VALIDATION.md).
The speaker hum is still a separate unresolved issue. I haven't tested prolonged
use at high brightness, power loss during a journal write, or other board
revisions.
