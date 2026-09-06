#!/bin/sh
set -eu
/etc/init.d/S96motion-white stop
cli -s .nightMode.irCutPin1 8
cli -s .nightMode.irCutPin2 9
cli -s .nightMode.backlightPin 16
cli -s .nightMode.lightSensorPin 15
cli -s .nightMode.lightSensorInvert true
cli -s .nightMode.lightMonitor true
cli -s .nightMode.colorToGray true
cli -s .nightMode.irCutSingleInvert false
cli -s .motionDetect.enabled true
cli -s .motionDetect.sensitivity 1
cli -s .image.flip false
/etc/init.d/S95majestic restart
/etc/init.d/S96motion-white start
