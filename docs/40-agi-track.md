# EGA / AGI 軌技術設計（M1）

> 目標：讓 ScummVM 的 `agi` engine 在 640×400 hires 畫布上渲染 16×16 繁體中文（Big5），並用 content-keyed 方式把英文訊息換成中文。對應遊戲：LSL1 EGA 版（AGI 2.440）。
> 本文基於實讀 ScummVM AGI engine 原始碼（`engines/agi/{font,text,graphics}.cpp`）的架構分析。

## 1. AGI 文字渲染架構（實讀結論）

| 元件 | 位置 | 職責 |
|---|---|---|
| `GfxFont` | `font.cpp` | 載入 8×8（或 hires 16×16）點陣字，`_fontData` = 256 字 × N bytes；`_fontIsHires` 旗標 |
| `GfxMgr::drawCharacterOnDisplay()` | `graphics.cpp:1219` | **逐 pixel blit 單一字元**；已內建 `fontIsHires ? 16 : 8` 的字寬/字高/bytesPerChar 分支 |
| `GfxMgr::drawStringOnDisplay()` | `graphics.cpp:1187` | `while (*text)` **逐 byte** 畫字，x 每次 += `_displayFontWidth` |
| `GfxMgr::drawCharacter()` | `graphics.cpp:1160` | 文字格座標 → display 座標，給遊戲訊息用 |
| `TextMgr`（訊息/word-wrap） | `text.cpp` | 遊戲訊息進 text buffer、斷行，逐字送繪 |
| 640×400 upscale | `graphics.h:38` `DISPLAY_UPSCALED_640x400`；`_upscaledHires` | hires 顯示模式（Apple IIgs / Hercules 用）|

**兩個關鍵既有槓桿點（大幅降低工作量）：**
1. **hires 16×16 繪字路徑已存在**：`drawCharacterOnDisplay` 的 `fontIsHires` 分支已能畫 16×16、32 bytes/char 的字。中文 glyph 尺寸剛好對齊。
2. **LSL EGA 遊戲自帶 `HGC_FONT`**（Hercules 16×16 字）：代表遊戲可跑在 hires 模式，`_fontIsHires=true` 是自然狀態。

## 2. 中文化改動設計（兩層，仿 qfg-1 SCI 但適配 AGI）

### A. Big5 字型類別 `GfxFontChinese`（新檔 `font_chinese_agi.{h,cpp}`）
- 載入獨立 Big5 點陣檔（`Graphics::Big5Font::loadPrefixedRaw`，16×16，與 qfg-1 同格式，`build_cht.py` 烘）。
- ASCII（< 0x80）委派原 `GfxFont`；Big5 lead byte（0x81–0xFE）+ trail byte 查 Big5Font 取 16×16 glyph。

### B. 繪字迴圈改造（`graphics.cpp`）
- `drawStringOnDisplay()` 的 `while (*text)` 迴圈：偵測 `*text >= 0x81 && *text <= 0xFE` → 取 `text[0],text[1]` 兩 byte 當 Big5 碼，呼叫新的 `drawBig5CharacterOnDisplay(x, y, lead, trail, fg, bg)` 畫 16×16，x += 16（hires 對映）、text += 2；否則走原 ASCII 路徑、text += 1。
- `drawCharacter()`（文字格座標路徑，遊戲訊息用）同樣需支援雙 byte：因 AGI 是 40 欄字格，一個漢字視覺上佔 2 欄，需在 `TextMgr` 送字時以 2 欄步進（或改走 display 座標繪字繞過字格）。**這是 AGI 特有難點，SCI 沒有。**

### C. 內容替換（content-keyed，`text.cpp` + `agi.cpp`）
- 開機 `loadChtTranslation()`：讀遊戲目錄 `translation.tsv`（`<english>\t<big5>`），unescape `\n`，載入成 HashMap。
- `TextMgr` 取得要顯示的訊息字串後、送去斷行/繪字前，用英文原文當 key 查表命中即換成 Big5 譯文。
- key 必須與 AGI 送進來的原文完全一致（AGI LOGIC 訊息解密後的字面）。

### D. 語言與模式觸發
- `--language=tw` → `getLanguage()==ZH_TWN`（沿用 qfg-1 的 CLI 覆蓋機制）。
- 強制 `_upscaledHires = DISPLAY_UPSCALED_640x400` + Big5 字型路徑（ZH_TWN 時）。

## 3. 文字抽取（AGI 專用，新做 `tools/extract_agi.py`）

- AGI 訊息藏在 **LOGIC 資源**，以 **avis durgan** XOR 字串加密。ScummVM 的 `words.cpp`/`logic.cpp` 已有解密邏輯可參考。
- 方案：優先加引擎 dump hook（`AGI_DUMP_MSG=<dir>` 環境變數，仿 qfg-1 `SCI_DUMP_RES`），用引擎自帶解密器 dump 每個 LOGIC 的訊息表 → 逐則英文當 key。dump 完即退（docker `timeout` 包）。
- 備援：純 Python 解 LOGIC 格式（AGI vol 格式 + avis durgan XOR），成本較高但不依賴 build。

## 4. 待驗證問題（M1 spike 要實測回答）

1. **40 欄字格 vs 雙 byte 漢字**：AGI `TextMgr` 的斷行/游標推進以「字元」為單位；漢字佔 2 欄需改 `TextMgr` 步進，否則排版錯位、換行點算錯。這是本軌最大不確定點。
2. **文字視窗寬度**：AGI 訊息視窗以字格寬計算，漢字塞入後視窗寬度/位置是否需重算。
3. **`putFontPixelOnDisplay` 在 640×400 的座標**：hires pixel 映射是否需額外處理（對照 Hercules 既有 16×16 已證可行）。
4. **輸入 / parser**：AGI 是文字冒險，玩家打指令。中文化階段先只做「輸出中文」，玩家指令維持英文（parser 走 WORDS.TOK，不在本階段動）。

## 5. M1 spike 驗收（rulebook 65：對 reference 實機實測）

✅ **M1 已完成（2026-07-10）**：實機截圖 `docs/m1-first-chinese-age-prompt.png` — 年齡驗證提示 `How old are you?`（L6.1）正確渲染為中文「你今年幾歲？」，16×16 Big5，標題圖與背景正常。

## 6. M1 實作過程的關鍵發現（踩雷，M2 前務必知道）

1. **中文啟用改用「字型檔存在」而非 `--language=tw`（重要，與 qfg-1 不同）**：
   LSL1 AGI 在 ScummVM 走 **fallback 偵測**（log：`Couldn't identify game 'lsl1' ... fallback matching agi-fanmade`）。一旦把 target 語言設成**任何非英文**（tw、de 皆然），遊戲就**無法啟動、退回 launcher**——這是 ScummVM AGI fallback 偵測的語言 gating，與中文無關。
   解法：`GfxMgr::loadChtResources()` 以遊戲目錄有無 `lsl_big5.fnt` 為開關，遊戲以英文正常啟動，中文照樣生效。**不需 `--language`**。（qfg-1 的 SCI 遊戲是正常偵測，故 `--language=tw` 可行；AGI 這條不適用。）

2. **暫不強制 640×400 hi-res（D-1 的 EGA 部分需重議）**：
   在 `initVideo` 對 EGA 遊戲強制 `DISPLAY_UPSCALED_640x400` 會讓**整個畫面全黑**（背景不渲染）。`render_BlockEGA` 雖有 hires 分支，但強制套用仍與 IIgs/Herc 平台繪圖耦合，根因未解。
   目前走**原生 320×200 直接畫 16×16 Big5**（一個漢字佔 2 個 8px 字格，`column += 2`），靠 ScummVM 視窗縮放放大顯示——與 qfg-1 SCI 原生路線一致、可讀、背景正常。**640×400 hi-res 留待後續 debug**（M2/M3 或獨立 spike）。

3. **headless 驗證要點**：dummy video driver 下 AGI engine 不跑（要 Xvfb）；輸出要 `stdbuf -oL -eL` 行緩衝寫檔（timeout kill 會吞掉未 flush 的 log）；`--auto-detect` 只會停在 launcher，要先 `--add` 再用 target 名 `lsl1` 啟動。

4. **抽字**：`tools/extract_agi.py` 已能 100% 乾淨解出 1850 則訊息（LOGIC 訊息區整塊連續 XOR "Avis Durgan"，pointer table 不加密）。key 用英文原文（含尾隨空白，如 `How old are you?  ` 有 2 個尾隨空白）。
