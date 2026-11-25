#!/bin/bash

sleep 5

DEVICE_ID=$(xinput list | awk '/wch.cn TouchScreen/{
    for(i=1;i<=NF;i++)
        if($i ~ /^id=/){
            sub("id=","",$i)
            print $i
        }
}' | sort -n | head -n1)

xinput set-prop $DEVICE_ID "Coordinate Transformation Matrix" -1 0 1 0 -1 1 0 0 1
xinput map-to-output $DEVICE_ID HDMI-2

nohup firefox "https://scorer.darthelfer.de/" > /dev/null 2>&1 &

sleep 15

WIN_ID=$(wmctrl -l | grep Firefox | tail -n 1 | awk '{print $1}')

wmctrl -i -r $WIN_ID -e 0,0,0,-1,-1

sleep 1
xdotool mousemove 150 750
xdotool click 1

sleep 1
xdotool mousemove 860 550
xdotool click 1

sleep 4

WIN_ID=$(wmctrl -l | grep Firefox | tail -n 1 | awk '{print $1}')

wmctrl -i -r $WIN_ID -e 0,1920,0,1,-1

sleep 1

wmctrl -i -r $WIN_ID -b toggle,fullscreen