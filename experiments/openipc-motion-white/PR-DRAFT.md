Title: experiments: add persistent HiseeU motion white-light control

On the HiseeU G5C-LQ/S38 camera, OpenIPC's existing IR night mode did not provide
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
5,206,016-byte rootfs). The owner reports working nighttime operation and
persistence after reboot on the SC223A/GK7205V200-family HiseeU camera. Evidence
and its limits are documented in `docs/HARDWARE.md` and `docs/VALIDATION.md`.

This is a sandbox experiment. Single-device support belongs in OpenIPC/builder;
this PR does not register a generic firmware package or claim readiness for a
shared OpenIPC/firmware merge. See `docs/OPENIPC-COMPLIANCE.md` for the later
builder integration requirements.
