#!/bin/bash

# @raycast.schemaVersion 1
# @raycast.title Pull Mini Clipboard
# @raycast.mode silent
# @raycast.icon 📋
# @raycast.packageName Clipboard

# Pulls the Mac mini's clipboard into this laptop's clipboard
ssh -o BatchMode=yes -o ConnectTimeout=5 trenthaines@100.64.101.124 pbpaste | pbcopy
