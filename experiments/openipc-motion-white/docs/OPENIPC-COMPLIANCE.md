# OpenIPC publication review

Reviewed against the firmware checkout's `AGENTS.md`, `best_practices.md` and
`pr_compliance_checklist.yaml` at commit
`2a0d5ca9a55a817fa6e9f62504425756fa9553ff`, and the public
[OpenIPC/builder device-registration requirements](https://github.com/OpenIPC/builder#requirements-for-registration-of-new-devices).

## Intended destination

This change is an experiment for `LordMephisto94/sandbox`, on its own branch
based on `main`. It does not alter the LLDP branch or add a shared firmware
package. [OpenIPC/sandbox](https://github.com/OpenIPC/sandbox) is the project's
repository for experiments.

It is **not an upstream-ready OpenIPC/firmware PR**. Firmware's rules explicitly
place single-retail-camera support in OpenIPC/builder. Installing a private
post-build hook under firmware's `contrib/` for local use did not waive that rule.
The published wrapper now runs directly from sandbox against a supplied firmware
checkout, avoiding an implication that the profile belongs in the shared tree.

## Applicable checks

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
| Hardware evidence | Owner reports live operation and reboot persistence; supplied traces and limits documented honestly |
| Credentials and EULA | No credentials, private camera backups, setup bypass, or automatic license acceptance added |

## Requirements for a later upstream builder submission

The current source-only sandbox publication must not be described as satisfying
all firmware merge gates. An upstream device integration still needs:

1. A device directory/profile in builder's supported layout, with per-device
   defconfig, customizer and excludes file as required by builder.
2. A proper package `Config.in` / `.mk` wired into that device's defconfig, with
   reviewable upstream provenance and an immutable source version where fetched.
   The explicit sandbox build wrapper is not a substitute for that firmware gate.
3. A complete build and flash-size validation using that exact builder profile.
4. Redacted post-reboot camera logs and identification accompanying the owner's
   operation report, plus any additional evidence requested by maintainers.

The existing local-image report cannot be relabelled as a test of a future
builder package. Maintainer approval is not implied by this review. Publishing
this experiment to the requested sandbox fork and upstreaming a supported device
profile are separate steps.
