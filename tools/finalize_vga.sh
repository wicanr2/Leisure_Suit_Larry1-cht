#!/usr/bin/env bash
# M4 VGA 收尾：recover vbatch → 合併(reuse 381 + 新翻) → 烘全字型 → 部署 game/vga。
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== 0) recover vbatch 格式 =="
python3 tools/recover_batches.py translation/vbatch v
echo "== 1) 合併（skeleton + reuse-only + vbatch fix）=="
python3 tools/merge_translations.py translation/vga-skeleton.tsv translation/lsl1-vga-full.tsv \
    translation/vga-reuse-only.tsv translation/vbatch/v*.fix.tsv
echo "== 2) 烘全字型 =="
python3 tools/build_cht.py translation/lsl1-vga-full.tsv fonts_vga --size 16
echo "== 3) 部署 game/vga =="
cp fonts_vga/qfg1_big5.fnt game/vga/lsl1_big5.fnt
cp fonts_vga/translation.tsv game/vga/translation.tsv
echo "完成。"
