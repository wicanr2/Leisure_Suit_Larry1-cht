#!/usr/bin/env bash
set -u
export DISPLAY=:99 HOME=/tmp
mkdir -p /out/f8
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --render-mode=ega --savepath=/out/saves/ega --save-slot=1 lsl1 >/out/f8_ega.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
K(){ xdotool key --window "$WID" --clearmodifiers "$@" 2>/dev/null; }
TYPE(){ xdotool type --window "$WID" --delay 50 "$1" 2>/dev/null; }
shot(){ import -window "$WID" "/out/f8/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/f8/$1 2>/dev/null))"; }
# 觸發一個中文旁白框
TYPE "look"; sleep 0.4; K Return; sleep 3
shot 1_cht.png
# F8 -> 應即時翻成英文
K F8; sleep 1.5
shot 2_eng.png
# F8 -> 翻回中文
K F8; sleep 1.5
shot 3_cht_again.png
kill $GPID 2>/dev/null
echo "=== done ==="
