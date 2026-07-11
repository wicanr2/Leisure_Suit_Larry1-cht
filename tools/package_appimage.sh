#!/usr/bin/env bash
# 把 patched ScummVM + 遊戲資料 + 中文字型/翻譯 打包成雙擊即玩的 AppImage。
# 完整包（含遊戲資料）→ dist-all，不上 GitHub。
# 用法: package_appimage.sh <ega|vga>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/pkg_common.sh"   # stage_mt32_rom(完整包附 MT-32 ROM)
ED="${1:?用法: package_appimage.sh <ega|vga>}"
STAGE="$ROOT/build/appimage"; DIST="$ROOT/dist-all"
mkdir -p "$STAGE" "$DIST"

case "$ED" in
  ega) LABEL="幻想空間-EGA"; TARGET="lsl1";    RENDER="--render-mode=ega"; LANGOPT="" ;;
  vga) LABEL="幻想空間-VGA"; TARGET="lsl1sci"; RENDER="";                  LANGOPT="--language=tw" ;;
  *) echo "edition 需 ega 或 vga"; exit 1 ;;
esac

APPDIR="$STAGE/AppDir-$ED"
rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/game"

echo ">> 複製 scummvm + strip"
cp "$ROOT/scummvm-src/scummvm" "$APPDIR/usr/bin/scummvm"
docker run --rm -v "$APPDIR/usr/bin:/b" qfg1-capture strip /b/scummvm 2>/dev/null || true

echo ">> 收集共享庫（qfg1-capture 內 ldd，排除 glibc 核心）"
docker run --rm \
  -v "$APPDIR/usr/bin/scummvm:/collect/bin:ro" \
  -v "$APPDIR/usr/lib:/collect/out" \
  -v "$ROOT/tools/pkg_collect_libs.py:/collect/collect.py:ro" \
  -w /collect qfg1-capture python3 collect.py bin out
echo "   $(ls "$APPDIR/usr/lib" | wc -l) 個 .so"

echo ">> 放入遊戲資料 + 中文字型/翻譯"
cp -r "$ROOT/game/$ED/." "$APPDIR/usr/share/game/"

# MT-32 ROM（完整包才附；有 ROM 才把音效驅動預設成 mt32，否則無 ROM 會彈阻擋框）
MT32ARGS=""
if stage_mt32_rom "$APPDIR/usr/share/game"; then
  MT32ARGS="--music-driver=mt32 --extrapath=\"\$GAME\""
fi

# AppRun：首次執行把 bundled 遊戲加入設定並啟動中文 target
cat > "$APPDIR/AppRun" <<APPRUN
#!/bin/bash
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\${LD_LIBRARY_PATH:-}"
GAME="\$HERE/usr/share/game"
SCUMMVM="\$HERE/usr/bin/scummvm"
"\$SCUMMVM" --add --path="\$GAME" >/dev/null 2>&1 || true
exec "\$SCUMMVM" $RENDER $LANGOPT $MT32ARGS "$TARGET" "\$@"
APPRUN
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/lsl1-cht.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=$LABEL
Comment=Leisure Suit Larry 1 (幻想空間) 繁體中文化 — ScummVM patch
Exec=AppRun
Icon=lsl1-cht
Categories=Game;
Terminal=false
DESK
cp "$ROOT/tools/assets/icon.png" "$APPDIR/lsl1-cht.png"
ln -sf lsl1-cht.png "$APPDIR/.DirIcon"

OUT="$DIST/${LABEL}-x86_64.AppImage"; rm -f "$OUT"
echo ">> appimagetool 打包（--appimage-extract-and-run 免 FUSE）"
docker run --rm -v "$STAGE:/stage" -v "$ROOT/tools/.cache:/cache:ro" -e ARCH=x86_64 -w /stage \
  qfg1-build bash -c "apt-get update -qq >/dev/null && apt-get install -y -qq file >/dev/null && \
    /cache/appimagetool-x86_64.AppImage --appimage-extract-and-run 'AppDir-$ED' '/stage/$(basename "$OUT")'"
mv "$STAGE/$(basename "$OUT")" "$OUT" 2>/dev/null || true
chmod +x "$OUT" 2>/dev/null || true
echo ">> 完成: $OUT ($(du -h "$OUT" 2>/dev/null | cut -f1))"
