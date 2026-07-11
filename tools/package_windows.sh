#!/usr/bin/env bash
# 打包 Windows zip：strip 過的 scummvm.exe + DLL + 遊戲資料 + 中文字型/翻譯 + .bat 啟動器。
# 用法: package_windows.sh <ega|vga>   （需先 mingw build 出 scummvm-win/scummvm.exe）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/tools/pkg_common.sh"   # stage_mt32_rom(完整包附 MT-32 ROM)
ED="${1:?用法: package_windows.sh <ega|vga>}"
DIST="$ROOT/dist-all"; mkdir -p "$DIST"
EXE="$ROOT/scummvm-win/scummvm.exe"
[ -f "$EXE" ] || { echo "找不到 $EXE（先 mingw build）"; exit 1; }

case "$ED" in
  ega) LABEL="幻想空間-EGA"; TARGET="lsl1";    LAUNCH="--render-mode=ega" ;;
  vga) LABEL="幻想空間-VGA"; TARGET="lsl1sci"; LAUNCH="--language=tw" ;;
  *) echo "edition 需 ega 或 vga"; exit 1 ;;
esac

STAGE="$ROOT/build/win-$ED"; rm -rf "$STAGE"; mkdir -p "$STAGE/game"
cp "$EXE" "$STAGE/scummvm.exe"
docker run --rm -v "$STAGE:/s" qfg1-mingw x86_64-w64-mingw32-strip /s/scummvm.exe 2>/dev/null || true
docker run --rm qfg1-mingw cat /usr/x86_64-w64-mingw32/bin/SDL2.dll > "$STAGE/SDL2.dll"
docker run --rm qfg1-mingw cat /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll > "$STAGE/libwinpthread-1.dll"
cp -r "$ROOT/game/$ED/." "$STAGE/game/"

# MT-32 ROM（完整包才附；有 ROM 才把音效驅動預設成 mt32）
MT32ARGS=""
if stage_mt32_rom "$STAGE/game"; then
  MT32ARGS='--music-driver=mt32 --extrapath="%~dp0game"'
fi

# .bat 啟動器：自動加入 bundled 遊戲並啟動中文 target
cat > "$STAGE/玩-幻想空間-繁中.bat" <<BAT
@echo off
chcp 950 >nul
cd /d "%~dp0"
scummvm.exe --add --path="%~dp0game" >nul 2>&1
scummvm.exe $LAUNCH $MT32ARGS $TARGET
BAT

OUT="$DIST/${LABEL}-windows-x64.zip"; rm -f "$OUT"
( cd "$STAGE" && zip -qr "$OUT" . )
echo ">> 完成: $OUT ($(du -h "$OUT" | cut -f1))"
