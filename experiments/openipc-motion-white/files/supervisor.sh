#!/bin/sh
set -u
BASE=/usr/libexec/motion-white
LOCK=/tmp/motion-white.supervisor
mkdir "$LOCK" 2>/dev/null || exit 1
printf '%s\n' "$$" > "$LOCK/pid"
child=
ready() {
    sensor=$(cat /sys/class/gpio/gpio15/value 2>/dev/null) || return 1
    case "$sensor" in 0|1) ;; *) return 1;; esac
    data=$(curl --fail --silent --max-time 2 http://127.0.0.1/metrics) || return 1
    printf '%s\n' "$data" | awk '
        $1=="md_rects_acc_total" {c=$2}
        $1=="night_enabled" {n=$2}
        END {exit !(c~/^[0-9]+$/ && n~/^[01]$/)}'
}
wait_ready() {
    attempts=0
    while ! ready; do
        if [ "$attempts" = 0 ]; then
            logger -t motion-white 'Waiting for Majestic motion/night metrics and GPIO15'
        fi
        attempts=$(((attempts + 1) % 30))
        sleep 2 & child=$!; wait "$child"; child=
    done
}
finish() {
    trap - EXIT TERM INT HUP
    if [ -n "$child" ]; then kill -TERM "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :; fi
    sh "$BASE/recover.sh" || logger -t motion-white 'Night control recovery pending; journal retained'
    rm -f "$LOCK/pid"
    rmdir "$LOCK" 2>/dev/null || :
}
trap finish EXIT
trap 'exit 0' TERM INT HUP
# Recover before checking ENABLED so disabling also restores ordinary IR control.
while ! sh "$BASE/recover.sh"; do sleep 10 & child=$!; wait "$child"; child=; done
. /etc/motion-white.conf
[ "${ENABLED:-false}" = true ] || exit 0
while :; do
    # A stale trial lock is never stolen from a live process.
    if [ -f /tmp/motion-white.run/pid ]; then
        read -r old < /tmp/motion-white.run/pid
        case "$old" in ''|*[!0-9]*) exit 1;; esac
        if kill -0 "$old" 2>/dev/null; then
            logger -t motion-white 'Another controller is running; stop the trial before starting this service'
            exit 1
        fi
        # Allow an orphaned hardware lease to expire before starting again.
        sleep 5 & child=$!; wait "$child"; child=
        rm -f /tmp/motion-white.run/pid /tmp/motion-white.run/lease /tmp/motion-white.run/worker.log
        rmdir /tmp/motion-white.run 2>/dev/null || exit 1
    fi
    if sh "$BASE/recover.sh"; then
        wait_ready
        sh "$BASE/service.sh" --apply >/dev/null 2>&1 & child=$!
        wait "$child"; result=$?; child=
        logger -t motion-white "Controller exited ($result); retrying in 15s"
    fi
    sleep 15 & child=$!; wait "$child"; child=
done
