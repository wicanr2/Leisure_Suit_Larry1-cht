#!/usr/bin/env bash
set -u
export DISPLAY=:99 HOME=/tmp XDG_RUNTIME_DIR=/tmp
mkdir -p /out/f8v
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --language=tw --savepath=/out/saves/vga --save-slot=2 lsl1sci >/out/drink.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
mm(){ xdotool mousemove --window "$WID" "$1" "$2"; }
bar(){ mm 320 2; sleep 0.5; }
clk(){ xdotool click --window "$WID" 1; }
shot(){ import -window "$WID" "/out/f8v/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/f8v/$1))"; }
# 坐上吧台
bar; mm 30 22; sleep 0.4; clk; sleep 1
mm 300 415; sleep 0.4; clk; sleep 3
bar; mm 160 22; sleep 0.4; clk; sleep 1
mm 420 335; sleep 0.4; clk; sleep 4
# TALK 酒保 1 次 = 打招呼
bar; mm 225 22; sleep 0.4; clk; sleep 1
mm 335 230; sleep 0.4; clk; sleep 3
shot drink_1greet.png
xdotool key --window "$WID" Return; sleep 1
# TALK 酒保 2 次 = 點酒選單
bar; mm 225 22; sleep 0.4; clk; sleep 1
mm 335 230; sleep 0.4; clk; sleep 3
shot drink_2menu.png
kill $GPID 2>/dev/null
echo "=== done ==="
