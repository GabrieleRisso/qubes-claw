#!/bin/bash
# dom0-workspace-setup.sh — Move visyble windows to workspace 2
# Install as dom0 autostart: ~/.config/autostart/openclaw-workspace.desktop
#
# Waits for visyble windows to appear, then moves them to desktop 2 (index 1)

WORKSPACE=1  # 0-indexed: desktop 2 = index 1
VM_NAME="visyble"
MAX_WAIT=120
WAITED=0

sleep 15

while [ $WAITED -lt $MAX_WAIT ]; do
    WINDOWS=$(wmctrl -l 2>/dev/null | grep -i "\[$VM_NAME\]" | awk '{print $1}')
    if [ -n "$WINDOWS" ]; then
        for WID in $WINDOWS; do
            TITLE=$(wmctrl -l 2>/dev/null | grep "$WID" | cut -d' ' -f5-)
            wmctrl -i -r "$WID" -t $WORKSPACE 2>/dev/null
            echo "Moved $WID ($TITLE) to workspace $((WORKSPACE+1))"
        done
        break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "Timeout: no $VM_NAME windows found after ${MAX_WAIT}s"
fi
