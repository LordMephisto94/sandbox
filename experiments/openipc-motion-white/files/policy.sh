# Pure state policy, sourced by the daemon and host tests. Times are uptime
# seconds. Call mw_tick NOW COUNTER NIGHT SENSOR. Outputs via MW_ACTION.
mw_init() {
    MW_PREV=; MW_WHITE=0; MW_LAST=0; MW_SETTLE=0
    MW_AMBIENT=; MW_AMBIENT_SINCE=0; MW_ACTION=none
}
mw_tick() {
    MW_NOW=$1; MW_COUNT=$2; MW_NIGHT=$3; MW_SENSOR=$4; MW_ACTION=none
    if [ -z "$MW_PREV" ]; then MW_PREV=$MW_COUNT; return; fi
    if [ "$MW_COUNT" -lt "$MW_PREV" ]; then
        MW_PREV=$MW_COUNT
        if [ "$MW_WHITE" = 1 ]; then MW_ACTION=restore; MW_WHITE=0; fi
        MW_SETTLE=$((MW_NOW + IR_SETTLE_SECONDS)); MW_AMBIENT=
        return
    fi
    MW_MOVING=0
    [ "$MW_COUNT" -gt "$MW_PREV" ] && MW_MOVING=1
    MW_PREV=$MW_COUNT
    [ "$MW_NOW" -lt "$MW_SETTLE" ] && return
    if [ "$MW_WHITE" = 1 ]; then
        [ "$MW_MOVING" = 1 ] && MW_LAST=$MW_NOW
        if [ "$((MW_NOW - MW_LAST))" -ge "$HOLD_SECONDS" ]; then
            MW_ACTION=restore; MW_WHITE=0
            MW_SETTLE=$((MW_NOW + IR_SETTLE_SECONDS)); MW_AMBIENT=
        fi
        return
    fi
    # Ambient sensor is only trusted with white lighting off and settled.
    if [ "$MW_SENSOR" != "$MW_AMBIENT" ]; then
        MW_AMBIENT=$MW_SENSOR; MW_AMBIENT_SINCE=$MW_NOW
    fi
    MW_DESIRED=0
    [ "$MW_SENSOR" = "$NIGHT_SENSOR_VALUE" ] && MW_DESIRED=1
    if [ "$((MW_NOW - MW_AMBIENT_SINCE))" -ge "$AMBIENT_DELAY_SECONDS" ] &&
       [ "$MW_DESIRED" != "$MW_NIGHT" ]; then
        MW_ACTION=day
        [ "$MW_DESIRED" = 1 ] && MW_ACTION=night
        MW_SETTLE=$((MW_NOW + IR_SETTLE_SECONDS))
        return
    fi
    if [ "$MW_NIGHT" = 1 ] && [ "$MW_MOVING" = 1 ]; then
        MW_ACTION=white; MW_WHITE=1; MW_LAST=$MW_NOW
        MW_SETTLE=$((MW_NOW + SETTLE_SECONDS))
    fi
}
