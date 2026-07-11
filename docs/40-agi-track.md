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

2. **640×400 hi-res 畫布（D-1，已成功，顯示層 aspect 校正為 640×480）**：
   `initVideo` 在 `_chtEnabled` 時 `forceHires=true` → `DISPLAY_UPSCALED_640x400`，字格寬=16px，一個 16×16 中文字佔 1 格（`column += 1`）。背景由 `render_BlockEGA` 的 640x400 分支正常渲染，中文比例正確、清晰。
   > ⚠️ 曾誤判「強制 hires 使背景全黑」——**真因是語言 gating**（見上一條：當時用 `--language=tw` 觸發 cht，遊戲根本沒啟動）。改成檔案式 cht 開關後，遊戲以英文正常啟動，hires 完全正常。教訓：驗證 hires 前先確認遊戲有真的 launch 進 engine（log 要有 `Emulating Sierra AGI`）。

3. **headless 驗證要點**：dummy video driver 下 AGI engine 不跑（要 Xvfb）；輸出要 `stdbuf -oL -eL` 行緩衝寫檔（timeout kill 會吞掉未 flush 的 log）；`--auto-detect` 只會停在 launcher，要先 `--add` 再用 target 名 `lsl1` 啟動。

4. **抽字**：`tools/extract_agi.py` 已能 100% 乾淨解出 1850 則訊息（LOGIC 訊息區整塊連續 XOR "Avis Durgan"，pointer table 不加密）。key 用英文原文（含尾隨空白，如 `How old are you?  ` 有 2 個尾隨空白）。

## 7. 完整在地化收尾：非-LOGIC 文字 + 系統 UI/狀態列 + F8（2026-07-11）

LOGIC 對白 100% 譯完 ≠ 完整。玩家還會看到選單、道具欄、系統 UI、狀態列——這些不在 LOGIC 裡，是最容易漏的殘留英文。

### 7.1 AGI 文字的三個來源（少抽一個就露英文）
- **LOGIC 訊息**：`extract_agi.py`（見 §6.4）。對白主體。
- **OBJECT 道具名**（20 項，Wallet/Rose/Prophylactic…）：**OBJECT 檔也是 `Avis Durgan` XOR 加密**（同 WORDS.TOK）。解密後抽 null 結尾字串。顯示走 `InventoryMgr` → `_text->displayText(name)` → **會呼叫 `getChtTranslation`**，所以**加進 `translation/lsl1-ega-full.tsv` 就會翻，不用改引擎**。
- **SystemUI 引擎硬寫字串**：道具欄標題「You are carrying:」、暫停、存讀檔提示、狀態列 Score/Sound。在 `engines/agi/systemui.cpp` 建構子按語言 `switch` 寫死（有 RU/HE/FR 分支），**不走 content-key**，得自己加分支。

### 7.2 [HARD] systemUI 中文分支要判 `chtEnabled` 不判 `language`
- EGA 用「字型檔存在」啟用中文（§6.1），`getLanguage()` **不是** `ZH_TWN`，故 systemui 的 `switch(getLanguage())` 那個 `case ZH_TWN` 永遠不命中。
- 正解：switch 之後補 `if (_gfx->chtEnabled()) { _textInventoryYouAreCarrying = "…"; … }`（Big5 用 `\xNN` escape，mirror RU/HE/FR 寫法）。

### 7.3 [HARD] init 順序：`loadChtResources()` 要移到 `new SystemUI` 之前
- `agi.cpp` 原順序：`new SystemUI(...)` → `loadChtResources()`（設 `_chtEnabled=true`）。→ SystemUI 建構子讀 `chtEnabled` **還是 false**，中文分支不生效（但道具名正常，因為它是顯示時即時查表）。
- 正解：把 `_gfx->loadChtResources()` 前移到 `new SystemUI` 之前。它只開 `lsl_big5.fnt`/`translation.tsv`、建自己的 Big5Font，**不依賴 `_font->init()`**，可安全前移（仍在 `initVideo` 前）。

### 7.4 狀態列 Score/Sound 中文化（小改動、大提升）
- `TextMgr::statusDraw` 用的也是 `displayText` → **本就支援 Big5**。
- 設 `_textStatusScore = "得分:%v3 / %v7"`、`_textStatusSoundOn/Off`。**`%v3/%v7` 是 AGI 變數代換（分數），`stringPrintf` 會填，務必保留。** 中文較短，score@col1 / sound@col30 不撞。實機：`docs/scene-ega-status-cht.png`（「得分：0 / 222」「聲音：開」）。

### 7.5 F8 中英對照即時切換
- 獨立旗標 `_chtLangOn`（**別重用 `_chtEnabled`**，後者還牽動 hi-res 與 Big5 gate）。`getChtTranslation` 開頭 `if (!_chtEnabled || !_chtLangOn) return english;`。
- F8 在 `AgiEngine::processScummVMEvents` 的 `EVENT_KEYDOWN` 攔截並消費（不 enqueue 給遊戲），僅 `chtEnabled` 時攔。
- **當前訊息框原地即時重繪**：`TextMgr::messageBox` 入口快取英文原文+wanted 排版；F8 呼叫 `chtToggleRedraw()` → `drawMessageBox(getChtTranslation(原文))`。`drawMessageBox` 內部先 `closeWindow` 再畫，**可重入**。（SCI 端採「下一則生效」語意。）

### 7.6 [HARD] systemui 硬寫 Big5 要 clang-safe（macOS CI 專屬雷）

`systemui.cpp` 硬寫的 Big5 `\xNN` escape 在 **clang（macOS）** 上會炸、GCC(Linux)/mingw(Windows) 卻放過 → **本機測不出，只 macOS CI 爆**。

- 症狀：`engines/agi/systemui.cpp:NNN: error: hex escape sequence out of range`。
- 根因：clang 的 `\x` **貪婪吃後續所有 hex 數字**。中文逗號 `，`(=`\xA1\x41`) 直接接 `ESC`/`ENTER`（E 是 hex 字母）→ `\x41ESC` 讀成 `\x41E`(=0x41E>255)。
- 修法：**字面值串接打斷** `"\xA1\x41" "ESC"`（相鄰字面值接合、**位元組完全相同、不加字**、GCC/clang/mingw 皆可）。通則：任何 `\xNN` 後緊接 `[0-9a-fA-F]` 處都插 `" "`。
- 教訓：**引擎硬寫 Big5 / 加 C++20 語法後，第一條 macOS CI 一定實跑**（clang 比 GCC 嚴，見打包文件 §macOS）。修正 commit `b99bae1`；macOS CI run 通過（universal .app + dmg，含 MT-32 emulator）。
