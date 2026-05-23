#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Toggle Disable Sleep
# @raycast.mode silent
# @raycast.icon ☕️
# @raycast.packageName Power

current=$(pmset -g | awk '/SleepDisabled/ {print $2}')

if [ "$current" = "1" ]; then
    sudo pmset -a disablesleep 0
    osascript -e 'display notification "Macbook will sleep normally" with title "Sleep Enabled"'
else
    sudo pmset -a disablesleep 1
    osascript -e 'display notification "Macbook will stay on" with title "Sleep Disabled"'
fi
