#!/usr/bin/env bash
set -u
export DISPLAY=:99 HOME=/tmp
mkdir -p /out/inv
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --render-mode=ega --savepath=/out/saves/ega --save-slot=1 lsl1 >/out/inv.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
K(){ xdotool key --window "$WID" --clearmodifiers "$@" 2>/dev/null; }
TYPE(){ xdotool type --window "$WID" --delay 50 "$1" 2>/dev/null; }
shot(){ import -window "$WID" "/out/inv/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/inv/$1))"; }
# 嘗試 parser "inventory"
TYPE "inventory"; sleep 0.4; K Return; sleep 3
shot inv_typed.png
K Return; sleep 1
# 嘗試 Tab 鍵(AGI 常見道具鍵)
K Tab; sleep 3
shot inv_tab.png
kill $GPID 2>/dev/null
echo "=== done ==="
