#!/usr/bin/env bash
# 可重跑：VGA(SCI1) 「Larry 坐在 Lefty's 吧台、對酒保講話」的中文對白框截圖。
# 輸出 out/scene/vga/npc_dialogue.png（成品另複製到 docs/scene-vga-npc_dialogue.png）。
#
# === 為什麼不用 teleport（背景）===
# 舊 capture_scene_vga.sh 用 SCI debugger `room 110` teleport 進酒吧，會跳過房間初始化，
# 對酒保 TALK 只拿到「!」手勢或「坐下」提示，拿不到正常對白。
# 正解：從 room 100(門口) 合法「開門」進 room 110，酒保 actor 才被正常 setup。
#
# === 兩階段解耦 ===
# 階段 A（手動、只做一次，已完成）：從 slot 1(room 100 門口) 合法進店，存成 slot 2。
#   合法進店關鍵步驟（實測）：
#     1) 先把 Larry「走離」門口（例：Walk 到人行道 (300,415)），不要貼著門。
#     2) 選 Hand/Do(操作) icon，點門(quilted 紅門，約 window 165,245)。
#        Larry 會自己走過去「開門」→ 合法換場到 room 110。
#        ★直接對著門 Walk 或站在門口 Do 都不會換場；一定要「離開再 Do 門」。
#     3) 進店後遊戲仍在腳本動畫(handsOff)，GMM 會回「cannot be saved」；
#        Resume 等 Larry 站定(handsOn) 後再 Ctrl+F5 → Save → New Save(=slot 2) → 命名 → OK。
#   → 產生 out/saves/vga/lsl1sci.002 (slot 2 = 店內、酒保已初始化、可對話)。
#
# 階段 B（本腳本，可重跑）：載入 slot 2 → 坐上吧台空凳 → TALK 酒保 → 擷取中文對白框。
#
# === 座標系陷阱（重要）===
# Xvfb 下 scummvm window 位置在 (10,15)，不在原點。
# 用「絕對座標」xdotool mousemove X Y 會整體偏移 10,15，精準 UI(GMM 按鈕/icon) 會點空。
# → 一律用「視窗相對座標」 xdotool mousemove --window "$WID" X Y（與 import 截圖同一座標系）。
#
# 用法：
#   docker run -d --name lsl1-vga-cap-b --cpus=2 \
#     -v "$PWD/scummvm-src:/src" -v "$PWD/game/vga:/game" \
#     -v "$PWD/out:/out" -v "$PWD/tools:/tools" qfg1-capture sleep 3600
#   docker exec -d lsl1-vga-cap-b bash /tools/capture_vga_bartender.sh
#   ...等 ~40s 後看 out/scene/vga/npc_dialogue.png；收工： docker rm -f lsl1-vga-cap-b
# （容器一律具名，清理只 rm -f 自己這顆，勿用 ancestor 廣掃誤殺別的專案容器）
set -u
export DISPLAY=:99 HOME=/tmp XDG_RUNTIME_DIR=/tmp
mkdir -p /out/scene/vga
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
# 載入 slot 2 = 店內、酒保已初始化
/src/scummvm --language=tw --savepath=/out/saves/vga --save-slot=2 lsl1sci >/out/cap_vga_bartender.log 2>&1 &
sleep 9
WID=$(xdotool search --class scummvm | tail -1); echo "WID=$WID"
mm(){ xdotool mousemove --window "$WID" "$1" "$2"; }   # 視窗相對座標
bar(){ mm 320 2; sleep 1; }                            # 移到頂端喚出 icon bar
# icon bar：Walk=30,22  Look=95,22  Hand/Do=160,22  Talk=225,22 （皆 y=22）

# 1) 坐上空凳：先把 Larry 移到前方(離凳)，再 Do 空凳座墊，Larry 會走過去坐下。
bar; mm 30 22;  sleep 0.5; xdotool click 1; sleep 1       # Walk
mm 300 415;     sleep 0.5; xdotool click 1; sleep 3       # 走到前方中央(離開凳位)
bar; mm 160 22; sleep 0.5; xdotool click 1; sleep 1       # Hand/Do
mm 420 335;     sleep 0.5; xdotool click 1; sleep 4       # Do 中央空凳座墊 → Larry 走過去坐下(背對鏡頭)

# 2) TALK 酒保（吧台後白髮酒保 ~335,230）→ 「你親切地跟酒保打了聲招呼:『哈囉。』」
bar; mm 225 22; sleep 0.5; xdotool click 1; sleep 1       # Talk
mm 335 230;     sleep 0.5; xdotool click 1; sleep 1.5     # 點酒保
import -window "$WID" /out/scene/vga/npc_dialogue.png
echo "  npc_dialogue.png ($(stat -c%s /out/scene/vga/npc_dialogue.png 2>/dev/null))"
# 註：再點一下會進「What'll it be? Lefty」點酒選單，但該選單字串目前未中文化(英文)，
#     故成品停在「哈囉」問候這格中文對白。

# 收尾
pkill -f 'scummvm .*lsl1sci' 2>/dev/null
echo "=== done ==="
