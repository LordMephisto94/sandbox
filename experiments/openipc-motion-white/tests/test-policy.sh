#!/bin/sh
set -eu
. "$(dirname "$0")/../files/policy.sh"
HOLD_SECONDS=30 SETTLE_SECONDS=3 IR_SETTLE_SECONDS=3 AMBIENT_DELAY_SECONDS=3 NIGHT_SENSOR_VALUE=0
check() { [ "$MW_ACTION" = "$1" ] || { echo "Expected $1, got $MW_ACTION" >&2; exit 1; }; }
mw_init
mw_tick 0 100 1 0; check none # startup baseline does not trigger
mw_tick 1 100 1 0; check none
mw_tick 2 101 1 0; check white
mw_tick 3 999 0 1; check none # transition motion and own light ignored
mw_tick 5 999 0 1; check none
mw_tick 31 999 0 1; check none
mw_tick 32 999 0 1; check restore # exactly 30 after last accepted activity
mw_tick 34 1000 1 0; check none
mw_tick 35 1001 1 0; check white
mw_tick 39 1002 0 1; check none
mw_tick 68 1002 0 1; check none
mw_tick 69 1002 0 1; check restore
mw_tick 73 1003 1 0; check white
mw_tick 74 0 1 0; check restore # restart/reset never counts as movement
mw_init
mw_tick 0 0 0 1; check none
mw_tick 1 10 0 1; check none # daytime motion
mw_tick 2 10 0 0; check none
mw_tick 4 10 0 0; check none
mw_tick 5 10 0 0; check night # debounced darkness
mw_tick 8 10 1 1; check none
mw_tick 11 10 1 1; check day # debounced daylight
HOLD_SECONDS=60
mw_init
mw_tick 0 0 1 0; mw_tick 1 1 1 0; check white
mw_tick 60 1 0 1; check none
mw_tick 61 1 0 1; check restore
# Replay the user's night trace with corrected polarity. Last two samples
# extrapolate a quiet scene beyond the end of the supplied trace.
HOLD_SECONDS=30 NIGHT_SENSOR_VALUE=1
mw_init
mw_tick 2614 1199 1 1; check none
mw_tick 2616 1199 1 1; check none
mw_tick 2619 1199 1 1; check none
mw_tick 2625 1206 1 1; check white
mw_tick 2626 1247 1 1; check none
mw_tick 2627 1305 1 1; check none
mw_tick 2628 1424 1 1; check none
mw_tick 2637 1939 1 1; check none
mw_tick 2648 1939 1 1; check none
mw_tick 2649 1949 1 1; check none
mw_tick 2657 2177 1 1; check none
mw_tick 2686 2177 1 1; check none
mw_tick 2687 2177 1 1; check restore
mw_tick 2690 2177 0 0; check none
mw_tick 2693 2177 0 0; check none
# Exposure changes after IR restoration must not trigger another white cycle.
HOLD_SECONDS=30 IR_SETTLE_SECONDS=15 NIGHT_SENSOR_VALUE=1
mw_init
mw_tick 0 0 1 1; check none
mw_tick 1 1 1 1; check white
mw_tick 31 1 0 0; check restore
mw_tick 32 100 1 1; check none
mw_tick 40 200 1 1; check none
mw_tick 45 300 1 1; check none
mw_tick 46 300 1 1; check none # ignored increases do not leak past settling
mw_tick 47 301 1 1; check white # fresh activity can trigger afterward
echo 'Shell policy tests passed, including trace replay and 15-second IR recovery'
