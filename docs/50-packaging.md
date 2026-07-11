# M5 三平台打包狀態

> 交付政策（CLAUDE.md）：GitHub 只放 patch-only；完整遊戲包進 `dist-all/`（不上 git）。

## Linux AppImage ✅（已完成，實測可玩）

`tools/package_appimage.sh <ega|vga>` → 自包含 AppImage（patched scummvm + 收集的 .so + 遊戲資料 + 中文字型/翻譯 + AppRun 自動啟動中文 target）。

- 產出：`dist-all/幻想空間-EGA-x86_64.AppImage`（~12M）、`幻想空間-VGA-x86_64.AppImage`（~15M）。
- 實測：xvfb 下啟動，log 確認 `AGI-CHT: 載入 1466 則翻譯`（EGA）/ SCI target 執行，畫面非黑。
- 免 FUSE：`--appimage-extract-and-run`。

## Windows ✅（mingw 交叉編譯，已完成）

- docker `qfg1-mingw`（含 SDL2 mingw devel + 靜態 zlib）。
- **踩雷**：source 樹複製給 Windows build 時**不可排除 `config.guess`/`config.sub`**，否則 configure `Checking endianness... unknown` 直接失敗。
- configure：`--host=x86_64-w64-mingw32 --disable-all-engines --enable-engine=agi --enable-engine=sci --disable-detection-full --disable-mt32emu`。
- `tools/package_windows.sh <ega|vga>` → `scummvm.exe`(strip) + `SDL2.dll` + `libwinpthread-1.dll` + 遊戲資料 + 中文資產 + `.bat` 啟動器（自動 --add 遊戲並啟動中文 target）。
- 產出：`dist-all/幻想空間-EGA-windows-x64.zip`(~11M)、`幻想空間-VGA-windows-x64.zip`(~13M)。

## 推廣影片 🎬（`tools/make_promo.sh`）

- EGA / VGA 各一支，每版獨立 theme（EGA 霓虹青/桃、VGA 暖橘）。分鏡：標題卡 → 遊戲截圖幻燈片（配中文字幕）→ 中文金句卡 → 結尾卡。
- 靜態圖 + fade（不用 zoompan，避免 CPU 爆量）；`docker --cpus=2`、libx264 `-preset veryfast`。
- **[HARD] rulebook 93**：配樂用原版遊戲 AdLib 音樂（ScummVM `SDL_AUDIODRIVER=disk` 側錄），不自產。
- 產出：`dist-all/幻想空間-ega-promo.mp4`（29s, ~1.2M）、`幻想空間-vga-promo.mp4`（34s, ~1.5M）。
- **交付政策**：影片含原版音樂 → 只進 `dist-all/`（gitignore），公開散布前注意 Sierra 著作權。

## macOS 🍎（GitHub Actions，`.github/workflows/build-macos.yml`）

- [HARD] **不用 brew sdl2**（2026 起是 sdl2-compat shim → dylibbundler 抓不到 → 玩家端黑畫面）；CI 自編 pinned SDL2 2.30.9 源碼，universal 用「每弧各編 + lipo」。
- 已適配：configure 加 `--enable-engine=agi --enable-engine=sci`、引擎檢查含 AGI、命名 LSL1-CHT。
- 中文資料注入（`pkg_common.sh` `stage_cht_data` + `package_macos_data.sh`）已改為 LSL1：
  - 來源用版控 runtime 快照 `fonts/`(EGA)、`fonts_vga/`(VGA)，CI checkout 直接可用（`game/` 為 gitignore 拿不到）。
  - 字型改名成引擎實際 open 的檔名：EGA `lsl_big5.fnt`、VGA `lsl1_big5.fnt`；LSL1 無 view/pic 美術 patch。
  - README 執行指令按版正確：EGA `--render-mode=ega lsl1`（不帶 `--language`，AGI 非英文會無法啟動）、VGA `--language=tw lsl1sci`。
  - **已驗證**：staging 來源 `fonts/`,`fonts_vga/` 與已出貨 Linux/Windows 的 `game/ega`,`game/vga` 中文資料位元一致（md5 相符）→ 三平台不 drift。
- **待首次 CI 實跑**：SDL2 release tarball 網址 / ScummVM 版本 drift 可能需微調（見 workflow 註解），資料注入邏輯已本機驗證。
