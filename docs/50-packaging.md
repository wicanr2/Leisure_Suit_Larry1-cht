# M5 三平台打包狀態

> 交付政策（CLAUDE.md）：GitHub 只放 patch-only；完整遊戲包進 `dist-all/`（不上 git）。

## Linux AppImage ✅（已完成，實測可玩）

`tools/package_appimage.sh <ega|vga>` → 自包含 AppImage（patched scummvm + 收集的 .so + 遊戲資料 + 中文字型/翻譯 + AppRun 自動啟動中文 target）。

- 產出：`dist-all/幻想空間-EGA-x86_64.AppImage`（~12M）、`幻想空間-VGA-x86_64.AppImage`（~15M）。
- 實測：xvfb 下啟動，log 確認 `AGI-CHT: 載入 1466 則翻譯`（EGA）/ SCI target 執行，畫面非黑。
- 免 FUSE：`--appimage-extract-and-run`。

## Windows ⚙️（mingw 交叉編譯）

- docker `qfg1-mingw`（含 SDL2 mingw devel + 靜態 zlib）。
- **踩雷**：source 樹複製給 Windows build 時**不可排除 `config.guess`/`config.sub`**，否則 configure `Checking endianness... unknown` 直接失敗。
- configure：`--host=x86_64-w64-mingw32 --disable-all-engines --enable-engine=agi --enable-engine=sci --disable-detection-full --disable-mt32emu`。
- 產出 `scummvm.exe` + `SDL2.dll` + `libwinpthread-1.dll` + 遊戲資料 + 中文資產 + `.bat` 啟動器。

## macOS 🍎（GitHub Actions，`.github/workflows/build-macos.yml`）

- [HARD] **不用 brew sdl2**（2026 起是 sdl2-compat shim → dylibbundler 抓不到 → 玩家端黑畫面）；CI 自編 pinned SDL2 2.30.9 源碼，universal 用「每弧各編 + lipo」。
- 已適配：configure 加 `--enable-engine=agi --enable-engine=sci`、引擎檢查含 AGI、命名 LSL1-CHT。
- **待首次 CI 執行微調**：`tools/package_macos_data.sh` + `pkg_common.sh` 的 `stage_cht_data` 仍是 qfg-1 路徑（`qfg1_big5.fnt` / VGA view-pic patch），需改為 LSL1 的 `lsl_big5.fnt`(EGA)/`lsl1_big5.fnt`(VGA) 與 `translation/lsl1-*-full.tsv`。ScummVM.app universal build 部分已正確。
