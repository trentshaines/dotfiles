#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle Disable Sleep
# @raycast.mode silent
# @raycast.icon ☕️
# @raycast.packageName Power

current=$(pmset -g | awk '/SleepDisabled/ {print $2}')

if [ "$current" = "1" ]; then
    sudo pmset -a disablesleep 0
    echo "Sleep enabled — Macbook will sleep normally"
else
    sudo pmset -a disablesleep 1
    echo "☕️ Sleep disabled — Macbook will stay on"
fi
