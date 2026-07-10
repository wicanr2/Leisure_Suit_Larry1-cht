#!/usr/bin/env bash
# M2 收尾：合併全部 batch 譯文 → 烘全字型 → 部署到 game/ega。
# 用法（docker 外，主機）: bash tools/finalize_ega.sh
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== 0) 校正 batch 格式（去行號/多tab，對齊 source key）=="
python3 tools/recover_batches.py

echo "== 1) 合併 batch 譯文（用校正後的 .fix.tsv）=="
python3 tools/merge_translations.py translation/skeleton.tsv translation/lsl1-ega-full.tsv translation/batch/*.fix.tsv

echo "== 2) 烘全字型 + runtime tsv (Big5) =="
python3 tools/build_cht.py translation/lsl1-ega-full.tsv fonts --size 16

echo "== 3) 部署到 game/ega =="
cp fonts/qfg1_big5.fnt game/ega/lsl_big5.fnt
cp fonts/translation.tsv game/ega/translation.tsv
echo "完成。字型 $(ls -la fonts/qfg1_big5.fnt | awk '{print $5}') bytes，譯文 $(wc -l < fonts/translation.tsv) 則。"
