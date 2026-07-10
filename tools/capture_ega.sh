#!/usr/bin/env bash
# 在 qfg1-capture docker 內 headless 擷取 EGA(AGI) 中文化畫面（依 rulebook 35：有界、輸出檔、不開 GUI）。
# 用法（docker 外）:
#   docker run --rm -v $PWD/scummvm-src:/src -v $PWD/game/ega:/game -v $PWD/out:/out \
#     -v $PWD/tools:/tools qfg1-capture bash /tools/capture_ega.sh
# 前置：game/ega 內需有 lsl_big5.fnt + translation.tsv（中文由字型檔存在啟用，不需 --language）。
set -u
export DISPLAY=:99 HOME=/tmp
Xvfb :99 -screen 0 640x480x24 >/dev/null 2>&1 &
sleep 2
/src/scummvm --add --path=/game >/dev/null 2>&1
/src/scummvm --render-mode=ega lsl1 >/out/game.log 2>&1 &
WIN() { xdotool search --name ScummVM 2>/dev/null | tail -1; }
sleep 4                                              # 標題 pic
for i in 1 2 3 4; do
  xdotool key --window "$(WIN)" Return 2>/dev/null
  sleep 2
  import -window root "/out/cap_$i.png" 2>/dev/null
done
kill %1 2>/dev/null
grep -iE 'AGI-CHT|Emulating|Running Leisure' /out/game.log | head
