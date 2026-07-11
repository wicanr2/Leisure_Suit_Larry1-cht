#!/usr/bin/env bash
set -u
export DISPLAY=:99 HOME=/tmp
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 & sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --render-mode=ega --savepath=/out/saves/ega lsl1 >/out/av/log.txt 2>&1 &
GPID=$!; sleep 9
WID=$(xdotool search --class scummvm | tail -1)
K(){ xdotool key --window "$WID" --clearmodifiers "$@" 2>/dev/null; }
sleep 2; K Return; sleep 2; K Return; sleep 3; K Return; sleep 3
for i in $(seq 1 20); do K Return; sleep 1; done   # 足夠 Return 過完歡迎詞+進遊戲
sleep 3
import -window "$WID" /out/av/GAME.png 2>/dev/null; echo "GAME ($(stat -c%s /out/av/GAME.png))"
kill $GPID 2>/dev/null
