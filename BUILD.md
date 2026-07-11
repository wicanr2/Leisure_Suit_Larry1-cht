# 從零重建《幻想空間》中文化（開發者指南）

本包含中文化的**全部原始碼與工具**（patch-only），可在另一台機器完整重建。**不含原始遊戲資源**——請自備合法遊戲檔。

## 前置

- Docker（編譯全走 docker，不污染系統）
- 合法的《幻想空間》遊戲資料：
  - EGA 版（1987 AGI）：`LOGDIR`/`PICDIR`/`VIEWDIR`/`VOL.*`/`WORDS.TOK` 等 → 放 `game/ega/`
  - VGA 版（1991 SCI1）：`RESOURCE.MAP`/`RESOURCE.000-002` 等 → 放 `game/vga/`

## 一、建 docker build 環境

```bash
docker build -t qfg1-build   -f docker/Dockerfile.build   docker/   # debian12 + libsdl2-dev（Linux 原生編譯）
docker build -t qfg1-mingw   -f docker/Dockerfile.mingw   docker/   # mingw-w64 + SDL2 + 靜態 zlib（Windows 交叉編譯）
docker build -t qfg1-capture -f docker/Dockerfile.capture docker/   # + xvfb/imagemagick（headless 截圖）
```

## 二、取得並 patch ScummVM

```bash
bash tools/apply_patches.sh scummvm-src
# 自動 clone 官方 ScummVM @ pinned commit（patches/UPSTREAM_COMMIT.txt）
# 套用 0001-agi-cht + 0002-sci-cht + 放入 fontchinese_sci.{h,cpp}
```

## 三、編譯（Linux）

```bash
docker run --rm -v "$PWD/scummvm-src:/src" -w /src qfg1-build bash -c \
  './configure --disable-all-engines --enable-engine=agi --enable-engine=sci \
     --disable-detection-full && make -j$(nproc)'
```
> flag 順序重要：`--disable-all-engines` 必須在 `--enable-engine` 之前。
> **MT-32 慣例（所有 ScummVM 中文化都套用）**：configure **不要**帶 `--disable-mt32emu`，讓 Munt MT-32 模擬器編入，玩家有 Roland MT-32 音樂可用（比 AdLib 好很多）。以 `grep USE_MT32EMU config.h` 應為 `#define`。實際發聲需 MT-32 ROM（`MT32_CONTROL.ROM`+`MT32_PCM.ROM`，有版權不隨引擎散布）：
> - **完整包（dist-all）**：打包腳本自動從本機 `/home/anr2/cht/mt32` 附帶 ROM 並預設 `--music-driver=mt32`（開箱即用）。
> - **GitHub / patch-only**：不含 ROM；玩家自備 ROM 放進遊戲資料夾（或 ScummVM extrapath）後於音效選項選「Roland MT-32」。無 ROM 又硬設 mt32 會彈一次阻擋框再回退 AdLib，故 patch 包不設 mt32 預設。

## 四、烘中文字型 + 翻譯表

```bash
python3 tools/build_cht.py translation/lsl1-ega-full.tsv fonts     --size 16   # EGA
python3 tools/build_cht.py translation/lsl1-vga-full.tsv fonts_vga --size 16   # VGA
cp fonts/qfg1_big5.fnt game/ega/lsl_big5.fnt;   cp fonts/translation.tsv     game/ega/
cp fonts_vga/qfg1_big5.fnt game/vga/lsl1_big5.fnt; cp fonts_vga/translation.tsv game/vga/

# 標題疊圖：把設計師的「幻想空間」中文標題 PNG 烘成引擎可疊繪的 .ovl
# EGA(AGI 640x400 hi-res)：量化到 EGA-16 索引
python3 tools/build_title_overlay.py art/title/title-cht-ega.png game/ega/lsl_title.ovl --palette ega
cp game/ega/lsl_title.ovl fonts/
# VGA(SCI 320x200)：先縮到 320x200,再烘成內嵌調色盤(引擎 nearest-map 到當前 palette)
docker run --rm -v "$PWD:/w" -w /w game-video convert art/title/title-cht-vga.png -resize 320x200 art/title/title-cht-vga-320.png
python3 tools/build_title_overlay.py art/title/title-cht-vga-320.png game/vga/lsl_title.ovl --palette vga --colors 16
cp game/vga/lsl_title.ovl fonts_vga/
```
> 引擎顯示標題畫面時把 `lsl_title.ovl` 疊上：EGA 在 PictureMgr 顯示標題 pic 時、VGA 在 SCI 繪 Sturgeon
> 警告文字時觸發（缺檔自動略過，中文標題不影響其他中文化）。VGA 疊圖座標為 320x200 遊戲解析度。

## 五、執行

- EGA：`scummvm --add --path=game/ega && scummvm --render-mode=ega lsl1`（中文由字型檔存在啟用）
- VGA：`scummvm --add --path=game/vga && scummvm --language=tw lsl1sci`

## 六、打包

```bash
bash tools/package_appimage.sh ega   # → dist-all/幻想空間-EGA-x86_64.AppImage
bash tools/package_appimage.sh vga
bash tools/package_windows.sh  ega   # → dist-all/幻想空間-EGA-windows-x64.zip（需先 mingw build）
bash tools/package_windows.sh  vga
# macOS：push 觸發 .github/workflows/build-macos.yml（GitHub Actions）
```

## 重點踩雷（詳見 docs/40-agi-track.md、docs/50-packaging.md）

- AGI 非英文語言會使遊戲無法啟動 → EGA 中文用「字型檔存在」啟用，不靠 `--language`。
- SCI `fontchinese._big5Height` 必須 = build_cht 的 `--size`（16），否則位元組錯位缺字。
- Windows source 複製勿排除 `config.guess`/`config.sub`（否則 configure endianness unknown）。
- macOS CI 不用 brew sdl2（sdl2-compat shim），自編 pinned SDL2。
