# 《幻想空間》Leisure Suit Larry 1 繁體中文化 — 整體規劃書

> 版本：v1（可審閱初版，2026-07-10）
> 目標：把 1980–90 年代的經典《Leisure Suit Larry in the Land of the Lounge Lizards》繁體中文化，中文化僅以 ScummVM patch 形式交付，並打包 Windows / macOS / AppImage 三平台。
> 心態約束（[HARD]，rulebook 83）：**完整性 > 投報。兩個版本都要做，我們在保全歷史。**

---

## 1. 版本與引擎鑑定（已完成，這是全案的技術前提）

本案要中文化的是**同一款遊戲的兩個歷史版本**，但它們跑在 **ScummVM 的兩個不同引擎**上——這是本案與姊妹作 qfg-1 最大的差異，決定了兩條技術線不能共用同一套 patch。

| 版本 | 年份 | 引擎 | ScummVM engine | 原始檔 | 畫面 | 鑑定依據 |
|---|---|---|---|---|---|---|
| **EGA 版** | 1987 | **AGI 2.440** | `agi` | `LSL.zip` | 160×200（顯示 320×200），16 色 | `LOGDIR`/`PICDIR`/`VIEWDIR`/`SNDDIR` + `VOL.0-2` + `WORDS.TOK` + `OBJECT` + `AGIDATA.OVL`（內含 "Version 2.440"）|
| **VGA 版** | 1991 | **SCI1** | `sci` | `000741_leisure_suit_larry_1.7z` | 320×200，256 色 | `RESOURCE.MAP` + `RESOURCE.000/001/002` + `SCIDHUV.EXE` interpreter + `VGA320.DRV` + `VERSION`=2.1 |

> 關鍵結論：EGA 版是 **AGI 引擎**（不是 SCI0），VGA 版是 **SCI1**。兩者的字型系統、文字資源格式、繪字路徑完全不同，因此本案是**雙引擎、雙軌**專案。

---

## 2. 技術總路線

沿用姊妹作 qfg-1（同作者、已實證出貨的 Sierra 中文化 pipeline）的**兩層核心設計**，兩軌共用同一哲學、各自實作：

### 2.1 核心設計（兩軌共用）

**A. 只改 ScummVM 引擎，不動遊戲資源**
- 不解壓、不改 `RESOURCE.000` / `VOL.x`、不重打包原始資源。
- 在引擎的繪字路徑新增一條「繁中 + Big5」字型分支。
- 中文化 = 一份 ScummVM patch + 外部字型檔 + 外部翻譯表，全部放遊戲目錄。

**B. 執行期「內容比對替換」（content-keyed translation）**
- 外部 `translation.tsv`：每行 `<英文原文>\t<Big5 譯文>`，開機載入成 HashMap。
- 引擎繪字時，用**遊戲送進來的英文原文當 key** 查表，命中就換成中文。
- 好處：好維護、好 diff、不碰壓縮與 byte offset、翻譯與程式碼解耦。**這是整套做法最值得複製的決策。**

### 2.2 兩軌可複用度對照

| 項目 | VGA / SCI 軌 | EGA / AGI 軌 |
|---|---|---|
| 引擎繪字 hook | ✅ 直接沿用 qfg-1 `text16.cpp` 的 `DrawString`/`Box`/`DrawStatus` 三入口 | ⚠️ 需新做 `engines/agi/text.cpp` + `font.cpp` 的 hook |
| 中文字型類別 | ✅ 沿用 `GfxFontChinese`（委派 ASCII、Big5 lead byte 走 Big5Font）| ⚠️ AGI 字型是固定 8×8 點陣，需新寫 AGI 版繪字分支 |
| 文字抽取 | ✅ 沿用 `SCI_DUMP_RES` + `extract_strings.py`（SCI message/text）| ⚠️ AGI 文字在 LOGIC 資源（avis-durgan XOR 加密），需 AGI 專用抽字 |
| 內容替換機制 | ✅ 沿用 `loadChtTranslation()` / `getChtTranslation()` | ⚠️ 同機制移植到 AGI text 路徑 |
| 字型烘製 | ✅ 沿用 `build_cht.py`（TTF→Big5 prefixed-raw）| ✅ 同一支腳本，只是目標字寬高不同 |
| 打包/字型/翻譯工具鏈 | ✅ 兩軌共用 | ✅ 兩軌共用 |

> 結論：**VGA 軌是「移植 + 微調」（高信心，qfg-1 已證）；EGA 軌是「新開一條 AGI 路」（需 R&D spike）。** 建議先立 VGA 軌拿到第一句中文（風險最低），再啟 EGA 軌。

---

## 3. 畫布策略（已定案 D-1：兩軌都拉高到 640×400 hi-res 畫布）

**決策 D-1（2026-07-10 定案）**：兩軌都走 **2× 放大（→640×400）hi-res 畫布**繪製中文字，不走原生小字。理由：中文字在 640×400 有 16×16 空間，觀感一致、可讀性最佳，符合 rulebook 81「拉高畫布不縮字」。

### EGA / AGI 軌 — 切引擎內建 640×400 upscale 模式
- AGI 原生 8×8 英文字，中文塞不下（16×16 中文會佔 2×2 字格，破版）。
- **ScummVM 的 AGI engine 本來就內建 `DISPLAY_UPSCALED_640x400` 模式**（`engines/agi/graphics.h:38`），原是給 Apple IIgs / hi-res 字用的 → 直接沿用此模式畫 16×16 Big5，引擎已有鷹架，工作量比從零改小。

### VGA / SCI 軌 — 320×200 → 640×400 2× 放大
- 把 SCI 內部畫布 2× 放大到 640×400（整數倍，底圖 nearest 放大保持銳利），中文用 16×16 Big5 畫在放大後畫布。
- qfg-1 走的是「原生 320×200 直畫 16px Big5」；本案依 D-1 改走 2× hi-res。需處理：SCI UI/選單座標 2× 重映射、滑鼠命中區同步映射、`putFontPixel` 座標空間對齊（rulebook 81 §踩雷）。
- 相對 qfg-1 原生做法，此路多了畫布放大與座標映射的工作量，屬本案 VGA 軌與 qfg-1 的主要差異點。

---

## 4. 字型 pipeline

沿用 qfg-1 `tools/build_cht.py`：

- **字型來源（已定案 D-3：用系統字型）**：AR PL UMing TW 明體（系統已裝於 `/usr/share/fonts/truetype/arphic/uming.ttc`, face index = TW），古籍風，契合 1980s 復古氛圍，與 qfg-1 及先前中文化做法一致。
- **格式**：烘成 ScummVM 共用的 `Graphics::Big5Font::loadPrefixedRaw` 吃的 **prefixed-raw 點陣**（每字 = big-endian Big5 碼 + N 列 ×2 bytes，1bpp）。不是 SCI/AGI font resource、不是 atlas，是獨立檔放遊戲目錄。
- **尺寸**：VGA 軌 16 寬 × 15 高（對齊 `kChineseTraditionalWidth`）；EGA 軌依 640×400 模式的字格調整（待 spike 定）。
- **子集烘製**：只烘遊戲實際用到的字（qfg-1 約 2486 字），加 `NORMALIZE` 表修 LLM 常吐的非 Big5 字元、`fullwidthize` 把 CJK 相鄰半形標點轉全形。
- **編碼政策**：源碼維護用 **UTF-8**，build 時轉 **Big5** runtime（TAB/LF 不出現在 Big5，可安全當 TSV 分隔符）。

---

## 5. 文字抽取 → 翻譯 → 回寫

### VGA / SCI 軌（沿用 qfg-1）
1. `SCI_DUMP_RES=<dir>` 環境變數 hook → 用 ScummVM 自帶 SCI decompressor dump text/message 資源（dump 完即退，docker run 要 `timeout` 包住）。
2. `tools/extract_strings.py` 解析 SCI message V3 逐 record 取精確字串當 key（key 必須與 `GfxText16` 收到的原文完全一致，含標點、不含結尾 NUL）。
3. 分批 → haiku subagent 翻譯 → `merge_translations.py` 併回 → `translation.tsv`。

### EGA / AGI 軌（新做）
1. AGI 文字在 LOGIC 資源，經 avis-durgan XOR 解密後為訊息表。需寫 `tools/extract_agi.py`（或加 dump hook）抽出。
2. 同樣走 content-keyed，key = AGI 送進 `text.cpp` 繪字的原文。
3. AGI 訊息含硬換行 → TSV 存 `\n` escape，engine 端 unescape（同 qfg-1 SCI0/EGA 做法）。

> **翻譯內容可跨版沿用**：兩版是同一遊戲，對白高度重疊。先翻好一版（建議先 VGA），另一版 normalize 後比對沿用（qfg-1 EGA 沿用 VGA 達 40%）。

---

## 6. 打包（三平台 + dev-setup）

沿用 qfg-1 `tools/package.sh`，每軌各出一組（共 6+ 個平台包）：

| 平台 | 做法 | 本機可做？ |
|---|---|---|
| **AppImage** | 手工 AppDir + `pkg_collect_libs.py` 遞迴 ldd 收庫 + `appimagetool --appimage-extract-and-run`（免 FUSE）| ✅ |
| **Windows** | mingw 交叉編譯 `scummvm.exe` + `SDL2.dll` + `libwinpthread-1.dll` + 中文資料 + `.bat` 啟動器（自動 `--language=tw`）| ✅ |
| **macOS** | **GitHub Actions（macos-14 Apple Silicon）自編 pinned SDL2 源碼**，lipo universal，產 `.dmg`+`.tar.gz` 雙保底 | ⚠️ 需 CI |
| dev-setup | `patches/` + `apply_patches.sh` + `docker/` + `BUILD.md` 可攜開發包 | ✅ |

**macOS [HARD] 鐵則（rulebook + qfg-1 實證）**：**不能用 brew 的 sdl2**（2026 起是 sdl2-compat shim，runtime 才 dlopen libSDL3，dylibbundler 抓不到 → 玩家端黑畫面）。必須 CI 自編真 SDL2 源碼（qfg-1 用 2.30.9），加體積防呆（>1MB）+ `otool` 查無 SDL3。universal 用「每弧各編一次 + lipo」，不用單次雙 `-arch`。

**build 踩雷（硬）**：configure 時 `--disable-all-engines` 必須在 `--enable-engine=sci`（或 `agi`）**之前**；必加 `--disable-detection-full`（mt32emu 保留啟用，見下）。

**交付政策（CLAUDE.md）**：完整遊戲包**不上傳 GitHub**（放 `dist-all/`）；GitHub repo 只放 **patch-only** 版本。

---

## 7. 專案骨架（鏡像 qfg-1 / qog-2）

```
workplace/                       ← 自身為 git repo，push 到 github.com/wicanr2/Leisure_Suit_Larry1-cht
├── patches/
│   ├── 0001-sci-cht-zh_twn.patch    (VGA 軌，改編自 qfg-1)
│   ├── fontchinese.{h,cpp}          (SCI GfxFontChinese)
│   ├── 0002-agi-cht-zh_twn.patch    (EGA 軌，新做)
│   ├── apply_patches.sh
│   └── UPSTREAM_COMMIT.txt          (釘住 ScummVM base commit)
├── tools/          (build_cht.py / extract_strings.py / extract_agi.py / merge_translations.py / package.sh …)
├── fonts/          (cjk16.png/json 等烘出的點陣字)
├── translation/    (skeleton.tsv / batch/*.tsv / lsl1-vga-cht.tsv / lsl1-ega-cht.tsv)
├── docker/         (Dockerfile.build / .mingw / .capture / .macdata)
├── docs/           (00-overall-plan.md〔本檔〕/ 10-terminology.md / 20-engine-cjk-patch.md /
│                    30-text-pipeline.md / 40-agi-track.md / 50-promo-video-plan.md / lessons-learned.md)
├── extract/        (SCI_DUMP_RES / AGI dump 的原始抽字)
├── dist-all/       (完整平台包，git-ignored)
├── .github/workflows/build-macos.yml
├── WORKLIST.md     (交接/現況快照/踩雷筆記)
├── SETUP.md · BUILD.md · CONTEXT.md · CLAUDE.md
└── README.md       (圖文並茂遊戲介紹 + 手冊索引 + 技術 deep dive)
```

---

## 8. README 規劃（依 rulebook 80，三層 voice）

CLAUDE.md 要求：圖文並茂、詳細遊戲介紹、引言、盡量蒐羅當年中文資料、手冊索引。依 rulebook 80 分三個不可混用的 voice：

1. **Hero / 開場致詞**（第一人稱溫情信）：「還記得嗎？那個要你答對成人問題才能進遊戲的年代……」——1980s 台灣玩家與 LSL 的集體記憶。
2. **雜誌主體**（《第三波》《軟體世界》編輯人聲 + 1990s 電玩用語）：遊戲世界（Lost Wages 賭城）、角色（Larry Laffer）、經典橋段（計程車、賭場、旅館、答題防拷）、攻略要點（walkthrough）、當年沒有中文版的遺憾。
3. **技術 deep dive**（工程文件被動式）：雙引擎鑑定、`GfxFontChinese`、content-keyed 替換、`--language=tw`、patch 索引。

**素材蒐集任務**：LSL1 沒有官方中文手冊，需上網蒐集 manual + walkthrough + 當年中文評論（《第三波》《軟體世界》回顧文），找到「可惜沒中文版」那句當情感引爆點（rulebook 80 準則 6）。版權原文只摘要 + 引一句 + 標出處，不入 git。

---

## 9. 里程碑（執行序，已定案 D-2：先 EGA → 後 VGA）

| M | 目標 | 產出 | 風險 |
|---|---|---|---|
| **M0** | 環境與骨架 | git init + push、`apply_patches.sh` 能 clone+checkout pinned ScummVM、docker build 出可跑的 agi+sci ScummVM | 低 |
| **M1** | **EGA 軌 spike** | 切 640×400 upscale 模式 + AGI `text.cpp`/`font.cpp` hook + Big5 字型，抽 1 句 Larry 對白 → 翻 → 烘字 → `--language=tw` 實機看到第一句中文 | **高（R&D，本案最不確定點）** |
| **M2** | EGA 軌全量翻譯 | AGI 全量抽字（LOGIC 訊息解密）→ 分批翻 → 烘子集字 → 全遊戲中文 | 中（量大 + AGI 抽字新做）|
| **M3** | VGA 軌 spike | 移植 qfg-1 SCI patch + 2× 640×400 hi-res 畫布 + 座標映射，抽 1 句 → 實機看到第一句中文 | 中（qfg-1 有底，但畫布放大是新增工作）|
| **M4** | VGA 軌全量翻譯 | SCI 全量抽字 → 沿用 EGA 譯文 + 補譯 → 全遊戲中文 | 中 |
| **M5** | 三平台打包 | AppImage/Windows 本機、macOS CI；patch-only 上 GitHub、完整包進 dist-all | 中（macOS CI 首跑要調）|
| **M6** | README + 手冊 + 推廣 | 三層 voice README、手冊要點、（選）推廣影片 | 低 |

> 譯文沿用方向隨 D-2 反轉：先翻 EGA，VGA 再 normalize 比對沿用 EGA 譯文。

**實機驗證鐵則（rulebook 65）**：每個 milestone 的「完成」以**對 reference 實機實測**為準（真的進遊戲看到中文、玩得下去），不以測試綠或 headless dump 有輸出為準。retro playtest 走「正常玩家路徑」。

---

## 10. 風險與踩雷清單（取自 qfg-1 WORKLIST，複製即避坑）

1. **語言代碼是 `--language=tw`，不是 `zh_TW`**（CLI 會拒後者）。
2. **內容替換 key 要與引擎繪字收到的原文完全一致**（含標點、不含結尾 NUL）。
3. **SCI0/EGA/AGI 字串有硬換行** → TSV 存 `\n` escape，engine `loadChtTranslation` 要 unescape。
4. **dump hook 跑完不自退** → docker run 一律 `timeout` 包住，否則 headless 卡死。
5. **configure flag 順序**：`--disable-all-engines` 在 `--enable-engine=sci/agi` 前；必加 `--disable-detection-full`（mt32emu 保留啟用，見下）。
6. **半形標點走 ASCII 小字型** → build 時 fullwidthize；省略號用 `…` 非 `⋯`；簡體漏字（`赢→贏`）用 NORMALIZE 表修。
7. **先查證再斷言**（rulebook 62）：格式事實從 ScummVM 源碼 / 逐像素比對 PPM 抓根因，不憑印象猜。
8. **macOS 不用 brew sdl2**（見 §6），CI 自編源碼 SDL2。
9. **別 kill 別專案的 docker 容器**，只清 `lsl1-*` 前綴。
10. **EGA/AGI 軌是本案最大未知數**：AGI 的訊息加密、640×400 模式繪字、與 SCI 不同的 text 路徑都要實測驗證，M3 spike 若撞牆，換路（靜態追溯 62 / 截圖 oracle 64）不放棄（rulebook 83）。

---

## 11. 分工（依 CLAUDE.md 工作模式）

- **翻譯 / 打包 / 機械實作** → subagent + 便宜 model（haiku）分批執行。
- **美術**（點陣字微調、README 截圖對照、button sprite、推廣素材）→ Designer subagent。
- **引擎 patch / 逆向 / 架構決策** → 主 session 主導（第一性原理，不照抄 qfg-1 而是理解後移植）。

---

## 12. 決策紀錄（2026-07-10 定案）

- **D-1 畫布策略** ✅：兩軌都拉高到 **640×400 hi-res 畫布** 繪製 16×16 中文（VGA 走 2× 放大 + 座標映射；EGA 用引擎內建 640×400 upscale）。
- **D-2 執行序** ✅：**先 EGA(AGI) → 後 VGA(SCI)**，M0→M6 如上。
- **D-3 字型** ✅：用**系統字型 AR PL UMing TW 明體**（`uming.ttc`），與 qfg-1 及先前中文化一致。
- **D-4 起手** ✅：規劃書定稿 → push GitHub repo（`wicanr2/Leisure_Suit_Larry1-cht`）→ 開始推進 M0。

**總目標**：完成《幻想空間》EGA/VGA 雙版繁體中文化並三平台打包出貨。
