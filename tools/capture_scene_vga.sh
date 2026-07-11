#!/usr/bin/env bash
# 可重跑：VGA(SCI1) 三張場景截圖。輸出 out/scene/vga/{bar_exterior,bar_interior,npc_dialogue}.png
# 前提：out/saves/vga/lsl1sci.001（slot 1）= 已通過「年齡+版權」驗證、Larry 在 Lefty's 門口(room 100)的存檔。
#   此存檔於擷取當下用 ScummVM GMM(Ctrl+F5)在通過驗證後建立，讓本腳本免去每次答隨機驗證題。
# 用法：
#   timeout 120 docker run --rm --cpus=2 -v "$PWD/scummvm-src:/src" -v "$PWD/game/vga:/game" \
#     -v "$PWD/out:/out" -v "$PWD/tools:/tools" qfg1-capture bash /tools/capture_scene_vga.sh
# 關鍵：SCI debugger 只做「一次」teleport(room 110)；連續多次會不穩。room 110=Lefty's 內部(已知存在)。
#      切勿 teleport 到不存在的 room（SCI 會 fatal error 直接關閉遊戲）。
set -u
export DISPLAY=:99 HOME=/tmp XDG_RUNTIME_DIR=/tmp
mkdir -p /out/scene/vga
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --language=tw --savepath=/out/saves/vga --save-slot=1 lsl1sci >/out/cap_vga.log 2>&1 &
GPID=$!
sleep 8
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
shot(){ import -window "$WID" "/out/scene/vga/$1" 2>/dev/null; echo "  $1 ($(stat -c%s /out/scene/vga/$1 2>/dev/null))"; }

# 場景1：Lefty's 外觀 —— slot 1 直接載入 room 100，無需 teleport
shot bar_exterior.png

# 場景2：Lefty's 內部 —— 單次 teleport 到 room 110
xdotool key --window "$WID" ctrl+alt+d; sleep 1.5
xdotool type --window "$WID" --delay 40 "room 110"; sleep 0.3; xdotool key --window "$WID" Return; sleep 0.8
xdotool type --window "$WID" --delay 40 "exit";      sleep 0.3; xdotool key --window "$WID" Return; sleep 3
shot bar_interior.png

# 場景3：對酒保 TALK 中文對白（酒保在吧台後方 ~328,235；TALK icon 螢幕座標 ~205,22）
# 註：teleport 進 room 110 後酒保對白框偶爾不即時出現；如未出現(檔案偏大)請重跑，
#     或改用互動 docker exec 再點一次 TALK。已驗證的成品圖見 out/scene/vga/npc_dialogue.png。
sleep 2   # 讓 room 110 script 穩定再對話
for try in 1 2 3; do
  xdotool mousemove --window "$WID" 320 2; sleep 0.6
  xdotool mousemove --window "$WID" 205 22 click 1; sleep 0.6     # 選 TALK(嘴巴)
  xdotool mousemove --window "$WID" 328 235 click 1; sleep 4      # TALK 酒保
  import -window "$WID" /out/scene/vga/npc_dialogue.png
  sz=$(stat -c%s /out/scene/vga/npc_dialogue.png 2>/dev/null)
  echo "  npc_dialogue.png try$try ($sz)"
  [ "${sz:-0}" -lt 32000 ] && break || true    # 有對白框時檔案較小；否則重試
done

kill $GPID 2>/dev/null
echo "=== done ==="
