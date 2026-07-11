#!/usr/bin/env bash
# 可重跑：EGA(AGI) 三張場景截圖。輸出 out/scene/ega/{bar_exterior,bar_interior,npc_dialogue}.png
# 前提：out/saves/ega/lsl1.001（slot 1）= 已通過年齡+5題驗證、Larry 在 Lefty's 門口(room 1 開場)的存檔。
#   此存檔於擷取當下用 ScummVM GMM(Ctrl+F5)在通過驗證後建立；免去每次答隨機驗證題。
#   （AGI 的 debugger `room N` 只改變數不重繪畫面，故 EGA 場景一律走「真的走進門」而非 teleport。）
# 用法：
#   timeout 120 docker run --rm --cpus=2 -v "$PWD/scummvm-src:/src" -v "$PWD/game/ega:/game" \
#     -v "$PWD/out:/out" -v "$PWD/tools:/tools" qfg1-capture bash /tools/capture_scene_ega.sh
set -u
export DISPLAY=:99 HOME=/tmp
mkdir -p /out/scene/ega
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --render-mode=ega --savepath=/out/saves/ega --save-slot=1 lsl1 >/out/cap_ega.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
K(){ xdotool key --window "$WID" --clearmodifiers "$@" 2>/dev/null; }
TYPE(){ xdotool type --window "$WID" --delay 50 "$1" 2>/dev/null; }
shot(){ import -window "$WID" "/out/scene/ega/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/scene/ega/$1 2>/dev/null))"; }

# 場景1：Lefty's 外觀（存檔即開場，Larry 在門口）
shot bar_exterior.png

# 場景2：進 Lefty's —— AGI 解析器「open door」開門，把 Larry 對準門正下方再往上走進門
# 註：換場觸發對 Larry 起步位置/走路時間敏感；自動化偶爾只走到門口未進門(檔案偏小)。
#     如未進門請重跑，或改互動 docker exec 手動微調 click/Up。已驗證成品見 out/scene/ega/*.png。
TYPE "open door"; sleep 0.4; K Return; sleep 2   # -> 「好。」門開
K Return; sleep 1                                 # 關訊息
xdotool mousemove --window "$WID" 258 355 click 1; sleep 3   # 對準門正下方(click-walk)
K Up; sleep 10                                     # 直直往上走進門 -> 內部(需足夠時間觸發換場)
shot bar_interior.png

# 場景3：對酒保講話 -> 中文對白
TYPE "talk to bartender"; sleep 0.4; K Return; sleep 4
shot npc_dialogue.png

kill $GPID 2>/dev/null
echo "=== done ==="
