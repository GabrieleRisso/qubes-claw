#!/bin/bash
# dom0-workspace-setup.sh — Move OpenClaw windows to workspace 2
# Install as dom0 autostart: ~/.config/autostart/openclaw-workspace.desktop
#
# Moves visyble + openclaw-admin windows to desktop 2 (index 1)

WORKSPACE=1
MAX_WAIT=120
WAITED=0

sleep 15

while [ $WAITED -lt $MAX_WAIT ]; do
    MOVED=0
    for PATTERN in "OpenClaw" "visyble" "openclaw-admin" "Cursor" "Lain"; do
        WIDS=$(wmctrl -l 2>/dev/null | grep -i "$PATTERN" | awk '{print $1}')
        for WID in $WIDS; do
            CUR=$(wmctrl -l 2>/dev/null | grep "$WID" | awk '{print $2}')
            if [ "$CUR" != "$WORKSPACE" ]; then
                wmctrl -i -r "$WID" -t $WORKSPACE 2>/dev/null
                MOVED=$((MOVED + 1))
            fi
        done
    done

    if [ $MOVED -gt 0 ] || [ $WAITED -gt 30 ]; then
        break
    fi

    sleep 5
    WAITED=$((WAITED + 5))
done
