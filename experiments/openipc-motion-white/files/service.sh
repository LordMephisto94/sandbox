#!/bin/sh
# HiseeU G5C-LQ foreground lighting controller.
set -u
umask 077
BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
. /etc/motion-white.conf
JOURNAL=/etc/motion-white.restore
# Keep older camera configuration files usable after a script-only update.
IR_SETTLE_SECONDS=${IR_SETTLE_SECONDS:-15}
WHITE_HIGH_COUNT=${WHITE_HIGH_COUNT:-6}
. "$BASE/policy.sh"
APPLY=0
case "${1:---dry-run}" in --dry-run) ;; --apply) APPLY=1 ;; *) echo 'Usage: motion-white.sh [--dry-run|--apply]' >&2; exit 2;; esac
for setting in "$HOLD_SECONDS" "$SETTLE_SECONDS" "$IR_SETTLE_SECONDS" "$AMBIENT_DELAY_SECONDS"; do
    case "$setting" in ''|*[!0-9]*) echo 'Invalid timing setting' >&2; exit 2;; esac
    [ "$setting" -ge 1 ] && [ "$setting" -le 3600 ] || exit 2
done
case "$WHITE_HIGH_COUNT" in ''|*[!0-9]*) echo 'Invalid WHITE_HIGH_COUNT' >&2; exit 2;; esac
[ "$WHITE_HIGH_COUNT" -ge 2 ] && [ "$WHITE_HIGH_COUNT" -le 110 ] || { echo 'WHITE_HIGH_COUNT must be 2..110' >&2; exit 2; }
case "$NIGHT_SENSOR_VALUE" in 0|1) ;; *) exit 2;; esac
for cmd in curl awk cli mkfifo logger; do command -v "$cmd" >/dev/null || { echo "Missing $cmd" >&2; exit 1; }; done
RUN=/tmp/motion-white.run
mkdir "$RUN" || { echo 'Another instance or stale /tmp/motion-white.run exists; inspect before removing.' >&2; exit 1; }
printf '%s\n' "$$" > "$RUN/pid"
WORKER=; MONITOR_CHANGED=0; HARDWARE_STARTED=0; EXIT_STATUS=0
log() { if [ "$APPLY" = 1 ]; then logger -t motion-white "$*"; else printf '%s\n' "$*"; fi; }
http() { curl --fail --silent --show-error --max-time 2 "http://127.0.0.1$1"; }
mode() {
    target=$1
    answer=$(http "/night/$target") || return 1
    case "$target:$answer" in on:1|off:0) return 0;; *) log "Unexpected night API response: $answer"; return 1;; esac
}
gpio_option() {
    GPIO_OPTION=
    if [ -d /sys/class/gpio/gpio4 ]; then GPIO_OPTION=--reuse-gpio4; fi
}
stop_white() {
    if [ -n "$WORKER" ]; then
        exec 3>&-
        kill -TERM "$WORKER" 2>/dev/null || :
        wait "$WORKER" 2>/dev/null || :
        WORKER=
    fi
    gpio_option
    # Optional argument is either empty or the fixed literal --reuse-gpio4.
    "$BASE/white-led-test.arm" --apply $GPIO_OPTION off
}
cleanup() {
    trap - EXIT INT TERM HUP
    if [ "$APPLY" = 1 ] && [ "$HARDWARE_STARTED" = 1 ]; then
        stop_white || EXIT_STATUS=1
        if [ "$MONITOR_CHANGED" = 1 ]; then
            # Resume ordinary night control even if temporary colour mode failed.
            mode on || EXIT_STATUS=1
            if cli -s .nightMode.lightMonitor true && /etc/init.d/S95majestic reload; then
                rm -f "$JOURNAL"
                sync
            else
                EXIT_STATUS=1
            fi
            log 'Restored lightMonitor=true; Majestic resumes automatic day/night.'
        fi
    fi
    rm -f "$RUN/pid" "$RUN/lease" "$RUN/worker.log"
    rmdir "$RUN" 2>/dev/null || :
    exit "$EXIT_STATUS"
}
trap cleanup EXIT
trap 'EXIT_STATUS=130; exit' INT
trap 'EXIT_STATUS=143; exit' TERM HUP
fail() { log "ERROR: $*"; [ ! -r "$RUN/worker.log" ] || logger -t motion-white < "$RUN/worker.log"; EXIT_STATUS=1; exit; }
metrics() {
    data=$(http /metrics) || return 1
    parsed=$(printf '%s\n' "$data" | awk '$1=="md_rects_acc_total"{c=$2} $1=="night_enabled"{n=$2} END{if(c~/^[0-9]+$/ && n~/^[01]$/) print c,n; else exit 1}') || return 1
    set -- $parsed
    COUNTER=$1; NIGHT=$2
    SENSOR=$(cat /sys/class/gpio/gpio15/value) || return 1
    case "$SENSOR" in 0|1) ;; *) return 1;; esac
    read -r uptime_seconds ignored < /proc/uptime || return 1
    NOW=${uptime_seconds%%.*}
}
[ "$(cli -g .motionDetect.enabled)" = true ] || fail 'Enable motion detection first.'
metrics || fail 'Cannot read motion/night metrics and GPIO15.'
log "mode=$APPLY hold=${HOLD_SECONDS}s high_count=$WHITE_HIGH_COUNT/111 night=$NIGHT sensor15=$SENSOR counter=$COUNTER"
if [ "$APPLY" = 1 ]; then
    [ -x "$BASE/white-led-test.arm" ] || fail 'Missing white-led-test.arm'
    [ "$(cli -g .nightMode.lightMonitor)" = true ] || fail 'Expected lightMonitor=true before startup; recover prior run first.'
    [ "$(cli -g .nightMode.irCutPin1)" = 8 ] &&
    [ "$(cli -g .nightMode.irCutPin2)" = 9 ] &&
    [ "$(cli -g .nightMode.backlightPin)" = 16 ] &&
    [ "$(cli -g .nightMode.lightSensorPin)" = 15 ] || fail 'Board configuration mismatch.'
    [ "$(cat /sys/class/gpio/gpio15/active_low)" = 0 ] || fail 'Unexpected GPIO15 polarity.'
    initial_dark=0; [ "$SENSOR" = "$NIGHT_SENSOR_VALUE" ] && initial_dark=1
    [ "$initial_dark" = "$NIGHT" ] || fail 'Sensor polarity/state does not agree with Majestic; check dry run.'
    HARDWARE_STARTED=1
    stop_white || fail 'Cannot establish white-off state.'
    # Only two configuration writes per run, not per motion event.
    printf 'true\n' > "$JOURNAL" || fail 'Cannot journal automatic night control.'
    sync
    MONITOR_CHANGED=1
    cli -s .nightMode.lightMonitor false || fail 'Cannot suspend automatic night controller.'
    /etc/init.d/S95majestic reload || fail 'Cannot reload Majestic.'
    sleep 3
    metrics || fail 'Metrics unavailable after reload.'
fi
mw_init
while :; do
    metrics || fail 'Telemetry lost; stopping lighting and restoring night control.'
    if [ -n "$WORKER" ]; then
        kill -0 "$WORKER" 2>/dev/null || fail 'White LED worker exited.'
        printf 'H\n' >&3 || fail 'Cannot renew white LED lease.'
    fi
    mw_tick "$NOW" "$COUNTER" "$NIGHT" "$SENSOR"
    if [ "$APPLY" = 0 ] || [ "$MW_ACTION" != none ]; then
        log "uptime=$NOW counter=$COUNTER night=$NIGHT sensor15=$SENSOR white=$MW_WHITE action=$MW_ACTION"
    fi
    if [ "$APPLY" = 1 ]; then
        case "$MW_ACTION" in
            white)
                mode off || fail 'Cannot select colour/day mode.'
                mkfifo "$RUN/lease" || fail 'Cannot create lease pipe.'
                exec 3<> "$RUN/lease"
                gpio_option
                "$BASE/white-led-test.arm" --apply $GPIO_OPTION --high-count "$WHITE_HIGH_COUNT" lease < "$RUN/lease" 3>&- > "$RUN/worker.log" 2>&1 &
                WORKER=$!
                # Worker makes no HTTP calls; independent lease expires in 4s.
                printf 'H\n' >&3
                sleep 1
                grep -q '^READY$' "$RUN/worker.log" || fail 'White LED worker did not become ready.'
                ;;
            restore)
                stop_white || fail 'White-off failed.'
                rm -f "$RUN/lease"
                mode on || fail 'Cannot restore IR night mode.'
                ;;
            day) mode off || fail 'Cannot enter ambient day mode.';;
            night) mode on || fail 'Cannot enter ambient night mode.';;
        esac
        # Start settling after the actual hardware/API transition completes.
        case "$MW_ACTION" in
            white|restore|day|night)
                read -r completed_uptime ignored < /proc/uptime || fail 'Cannot read monotonic clock.'
                transition_delay=$IR_SETTLE_SECONDS
                [ "$MW_ACTION" != white ] || transition_delay=$SETTLE_SECONDS
                MW_SETTLE=$((${completed_uptime%%.*} + transition_delay))
                ;;
        esac
    fi
    sleep 1
done
