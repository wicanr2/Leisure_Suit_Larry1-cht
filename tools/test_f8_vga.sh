#!/usr/bin/env bash
set -u
export DISPLAY=:99 HOME=/tmp XDG_RUNTIME_DIR=/tmp
mkdir -p /out/f8v
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --language=tw --savepath=/out/saves/vga --save-slot=1 lsl1sci >/out/f8_vga.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
shot(){ import -window "$WID" "/out/f8v/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/f8v/$1 2>/dev/null))"; }
# 右鍵在場景循環動詞：walk->look。點在場景中央上方避免走動
cycle_look(){ xdotool mousemove --window "$WID" 320 150; xdotool click --window "$WID" 3; sleep 0.4; }
looksign(){ xdotool mousemove --window "$WID" 180 70 click 1; sleep 3; }
# 先循環一次看游標，截圖確認
cycle_look; import -window "$WID" /out/f8v/0_cursor.png
looksign
shot 1_cht.png
xdotool key --window "$WID" Return; sleep 1
# F8 -> 英文
xdotool key --window "$WID" F8; sleep 0.5
cycle_look; looksign
shot 2_eng.png
xdotool key --window "$WID" Return; sleep 1
# F8 -> 中文
xdotool key --window "$WID" F8; sleep 0.5
cycle_look; looksign
shot 3_cht.png
kill $GPID 2>/dev/null
echo "=== done ==="
