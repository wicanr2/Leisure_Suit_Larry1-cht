#!/usr/bin/env bash
# 把《幻想空間》繁中化引擎改動套進一份乾淨(或既有)的 ScummVM source 樹。
#
# 用法: apply_patches.sh <scummvm-src-dir>
#   - 若 <scummvm-src-dir> 不存在: 自動 clone 官方 scummvm/scummvm,
#     checkout patches/UPSTREAM_COMMIT.txt 記錄的 pinned commit。
#   - 若已存在: 直接對它套用,不動 git 狀態。
#
# 本專案為雙引擎(agi=EGA / sci=VGA),patch 依編號順序套用:
#   0001-agi-cht-zh_twn.patch  (EGA/AGI 軌)
#   0002-sci-cht-zh_twn.patch  (VGA/SCI 軌)
# 以及整檔新檔(fontchinese_agi.* / fontchinese.* 等)先 cp 再 patch。
set -euo pipefail
SRC="${1:?用法: apply_patches.sh <scummvm-src-dir>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$SRC" ]; then
  UPSTREAM="$(cat "$HERE/patches/UPSTREAM_COMMIT.txt")"
  echo ">> $SRC 不存在,clone 官方 ScummVM @ $UPSTREAM"
  git clone --config core.autocrlf=false --config core.eol=lf https://github.com/scummvm/scummvm.git "$SRC"
  git -C "$SRC" fetch --depth 1 origin "$UPSTREAM" 2>/dev/null || git -C "$SRC" fetch origin
  git -C "$SRC" checkout -f "$UPSTREAM"
fi

# 整檔新檔（VGA/SCI 軌的 GfxFontChinese）
if [ -f "$HERE/patches/fontchinese_sci.h" ]; then
  echo ">> 新檔 -> engines/sci/graphics/fontchinese.{h,cpp}"
  cp "$HERE/patches/fontchinese_sci.h"   "$SRC/engines/sci/graphics/fontchinese.h"
  cp "$HERE/patches/fontchinese_sci.cpp" "$SRC/engines/sci/graphics/fontchinese.cpp"
fi

# 編號 patch(依序;存在才套)
shopt -s nullglob
for p in "$HERE"/patches/[0-9][0-9][0-9][0-9]-*.patch; do
  echo ">> 套用 $(basename "$p")"
  patch -p1 -d "$SRC" < "$p"
done

echo ">> 完成。configure 範例(docker 內,flag 順序重要):"
echo "   ./configure --disable-all-engines --enable-engine=agi --enable-engine=sci --disable-detection-full --disable-mt32emu"
