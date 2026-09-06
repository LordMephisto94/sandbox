#!/bin/sh
set -eu
# Written before suspending Majestic, survives a power failure or SIGKILL.
if [ -f /etc/motion-white.restore ]; then
    cli -s .nightMode.lightMonitor true
    /etc/init.d/S95majestic reload
    rm -f /etc/motion-white.restore
    sync
fi
