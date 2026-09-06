Title: experiments: add persistent HiseeU motion white-light control

On my HiseeU G5C-LQ/S38 camera, OpenIPC's existing IR night mode did not provide
motion-triggered white illumination. This experiment switches to colour and
fixed-brightness white LEDs on nighttime motion, then restores IR after a
configurable hold (30 seconds by default). A 15-second IR settling interval
suppresses immediate retriggering from the exposure change.

Adds the PWM1 helper source, service, boot/recovery handling, configuration,
firmware build wrapper, tests and documentation. The branch is based on sandbox
main and contains no LLDP changes. Generated firmware, factory modules, trial
archives and private camera configuration are excluded.

Validation: 25 helper mock scenarios; policy/trace replay; four service scenarios;
journal recovery failures; supervisor restart/stop; shell syntax checks. The
original integrated image built within the 8 MiB NOR layout (1,824,240-byte kernel,
5,206,016-byte rootfs). I've flashed it onto my SC223A/GK7205V200-family HiseeU
camera and confirmed that nighttime lighting works and survives a reboot.
Hardware notes and test results are in `docs/HARDWARE.md` and
`docs/VALIDATION.md`.

I'm keeping this in sandbox for now. Adding it as a supported device belongs in
OpenIPC/builder and still needs a device profile and package integration. I've
listed that work in `docs/OPENIPC-COMPLIANCE.md`.
