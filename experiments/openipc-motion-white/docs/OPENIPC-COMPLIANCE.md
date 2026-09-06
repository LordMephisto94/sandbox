# OpenIPC integration notes

Reviewed against the firmware checkout's `AGENTS.md`, `best_practices.md` and
`pr_compliance_checklist.yaml` at commit
`2a0d5ca9a55a817fa6e9f62504425756fa9553ff`, and the public
[OpenIPC/builder device-registration requirements](https://github.com/OpenIPC/builder#requirements-for-registration-of-new-devices).

## Where this belongs

I'm keeping this in `LordMephisto94/sandbox` on a branch from `main`, separate
from my LLDP work. [OpenIPC/sandbox](https://github.com/OpenIPC/sandbox) is the
project's repository for experiments.

Support for a specific camera belongs in OpenIPC/builder. The local firmware
hook was enough to build and test my camera, but an upstream submission needs
proper device and package integration. The wrapper runs from this repository
and takes the firmware checkout as an argument.

## Checks

| Requirement | Result |
| --- | --- |
| Reviewable, buildable source | C helper compiled by the build hook; no binaries or extracted modules committed |
| No preload or vendor-code patching | No preload assignments, kallsyms hooks, or vendor module memory patches |
| No kernel patches | None added |
| Preserve shared camera defaults | No shared firmware source or generic defconfig changed |
| Keep changes scoped | LED experiment and its CI only; no LLDP code or commits included |
| Source provenance and licensing | New experiment source; MIT license retained; no factory executable shipped |
| Package source/version changes | None; existing firmware downloads and pins are not changed |
| Toolchain-wide flags | Existing firmware host-C compatibility settings retained by wrapper; no new target-wide codegen flags |
| Module conventions | Existing `open_pwm` is used; no insmod or new module introduced |
| Shell compatibility | Runtime scripts tested with BusyBox ash; post-build hook retains comment stripping |
| Flash budget | Tested kernel and squashfs fit 2 MiB / 5 MiB limits; wrapper enforces byte limits |
| Hardware evidence | I tested live operation and reboot persistence; logs and remaining tests are listed in HARDWARE.md |
| Credentials and EULA | No credentials, private camera backups, setup bypass, or automatic license acceptance added |

## Still needed for OpenIPC/builder

Before submitting this as a supported device, I need to:

1. Add the device profile in builder's layout, including its defconfig,
   customizer and excludes file.
2. Add a package `Config.in` and `.mk`, selected by that device's defconfig.
   Any downloaded source needs an upstream location and a fixed version.
3. Build that profile and check the resulting image sizes.
4. Include post-reboot camera identification and logs, with private details
   removed, alongside the lighting tests.

The tests here cover my current local build. The builder package will need its
own build and camera tests once it's ready.
