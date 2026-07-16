# VGA / SCI 軌：年齡驗證一次通過永久免答（破解方法）

> 對應 commit `cf9ac48`、patch `patches/0002-sci-cht-zh_twn.patch`。EGA/AGI 版的對等機制見 [`40-agi-track.md`](40-agi-track.md) §7（`v93` 自動填答）。本文記錄 **VGA/SCI 版怎麼逆向出來的**，方法本身可沿用到其他 SCI 老遊戲的問答式防拷。

## 1. 問題

《幻想空間》VGA 版一開場（script/room **720**）強制跑一段「成人驗證」：先選年齡，再答 3 題以上成人常識問答（Josh Mandel 出題，戲仿手冊防拷）。答錯就被踢回「請找大人」。每次開機都要重考，中文化後更煩——玩家目標是**通過一次後，之後開機自動答過，直接進遊戲**（片頭照留）。

## 2. 破解方法（先靜態、後動態，rulebook 62/64）

不是「背答案」——答案是隨機抽題的，背了也沒用。核心是**逆向出遊戲把正解暫存在哪，讓遊戲自己告訴引擎答案**。

### 2.1 靜態：dump 題庫資源，發現「首字元即正解」

先 dump 文字資源（`text.722` / `text.730` / `text.743`…，資源號隨版本/抽題而變），`strings` 一看就懂格式：

```
2The world is          ← 首字元 '2' = 正解是第 2 個選項
flat.
spherical.            ← 選項 2（正解）
a big place.
near Fresno.
4"Let It Be" was recorded by
the Rolling Stones.
the Monkees.
Creedence Clearwater.
the Beatles.          ← 選項 4（正解）
3Who lost a daughter but gained a "meathead?"
George Jefferson
Ronald Reagan
Archie Bunker        ← 選項 3（正解）
Ted Knight
```

**每道題文字的第一個字元就是正解編號（1–4）**。這是題庫的內建格式——遊戲載入題目時會把這個數字讀出來當「正確答案」。

### 2.2 動態：probe 出遊戲把正解存進 script 720 的 `local[4]`

在引擎 `GfxText16::Box()`（每次繪製對話文字都會過）掛一個暫時 probe，讀 room 720 的 script 區域變數並印出：

```cpp
Script *scr = segMan->getScriptIfLoaded(segMan->getScriptSegment(720));
reg_t *loc = scr->getLocalsBegin();   // local[0..n]
// 印 room、local[4]/[5]/[6]、當前文字
```

實測對照（每題後遊戲會顯示 `Correct`）：

| 題目文字 | 選項 | `local[4]` | 正解 |
|---|---|---|---|
| Who is not a famous musician? | a.Lawrence Welk b.Tommy Dorsey c.Les Brown **d.Steve Garvey** | 4 | d（棒球員，非音樂家）✓ |
| Which is non-alcoholic? | a.whiskey b.Grand Marnier **c.Perrier** d.tequila | 3 | c ✓ |
| Tom Hayden is | **a.Chicago Seven** … | 1 | a ✓ |

結論：**`local[4]` = 當前題目正解編號（= 2.1 的首字元）**；`local[5]` 隨換題改變（當作「新題」偵測用），選項回顯／`Correct`／空白畫面時 `local[5]` 不變。

## 3. 作答方式（兩種輸入不一樣，別搞混）

probe 也順便釐清了兩個階段的**輸入方式不同**：

| 階段 | 畫面 | 輸入 | 引擎自動作答 |
|---|---|---|---|
| 年齡選單 | 「So, how old are you?」6 選項 2×3 格（under 15 … over 100），提示「Use the TAB key to select」 | **TAB 移動 + ENTER 確認** | 偵測到 "how old are you" → `TAB×3 + ENTER`，選到「40 to 65」成人選項 |
| 成人問答 | a/b/c/d 字母選項 | **直接按字母鍵** | 讀 `local[4]` → 送出 `'a'+(L4-1)` |
| 片頭／警告 | Sturgeon 警告、標題 | 按任意鍵推進 | **不主動注入**，交玩家推進（保留片頭） |

年齡選單目標選「40 to 65」（第 4 格）而非「19 to 39」：**即使 TAB 數差一格，鄰格 19-39 / 66-99 仍是成人，容錯較大**。

## 4. 合成鍵注入（優先於玩家輸入）

在 `EventManager::getScummVMEvent()` **輪詢真實事件之前**注入合成鍵佇列（`chtVerifyPendingKey()`）：

```cpp
if (getLanguage()==ZH_TWN && chtVerified()) {
    int k = chtVerifyPendingKey();          // TAB/ENTER/字母，佇列空回 0
    if (k) { input.type = kSciEventKeyDown; input.character = k; return input; }
}
```

合成鍵一律先送，**玩家在旁邊亂按 ENTER 也搶不走年齡選單的焦點格**（否則會誤選 under 15 被踢）。`GfxText16::Box()` 在 kernel 繪字期間同步呼叫 `chtVerifyOnText()` 排入佇列——偵測與注入之間沒有事件迴圈空窗，`local` 一設好就作答，選項回顯用「佇列非空」擋掉重複。

## 5. 「已通過」判定與旗標

- 啟動時 `chtLoadVerifiedState()`：**有本遊戲存檔**（`<target>.###` 等）**或** `.chtok` 旗標檔存在 → `_chtVerified = true` 啟用自動作答。
- `chtVerifyRoomTick()`（每輪事件）：追蹤 room 720 進出，**曾進 720 又離開 = 通過** → 寫 `.chtok` 旗標。首次手動通過的玩家也會寫旗標，下次開機就自動答。
- 全新玩家（無存檔、無旗標）第一次仍照常手動作答，**驗證機制本身不失效**。

## 6. 實機驗證（rulebook 65：對 reference 實測）

預置 `.chtok` → autostart：log 顯示年齡選單 `TAB×3` → 6 題問答每題 `Correct` → `left age-verify room 720 → now room 100`（Lefty's 酒吧外開場）→ 寫旗標。反向（無旗標）：無 `auto-answer`，正常提示。截圖見 `docs/screenshot-vga-age-select-cht.png`。

## 7. Ctrl+Alt+X 一鍵略過（第一性原理：跳門，不答題）

上面的自動作答（flag 模式）保留片頭、逐題答對——但要**當場一鍵略過**時，逐題模擬會撞上題型繁多的坑
（常識題 TAB/字母、笑話題 `local[4]=0` 任意答案、手冊防拷題、各種過場需不同推進）。

**第一性原理**：年齡/密碼驗證只是一道「門」，把玩家擋在起始房間外。與其逐題答對，不如**直接跳到門後的
起始房間**（room 100，賴瑞在老左酒吧外）。這才是最單純可靠的解。

`chtVerifySkipNow()`（`sci.cpp`），在 room 720 按 Ctrl+Alt+X 時：
```cpp
_gamestate->setRoomNumber(100);                       // 除錯器 "room" 指令的同一機制（寫 newRoom 全域）
_gfxPorts->reset();                                    // 清掉殘留的年齡選單對話框 window（同 restore 路徑）
_gamestate->abortScriptProcessing = kAbortLoadGame;   // 打斷驗證控制項的 VM 等待迴圈 → 走 replay 恢復路徑
```
- **為何要 abort**：年齡選單/問答是在 VM 裡跑 event 阻塞迴圈等答案，光設 `setRoomNumber` 不會打斷它。
  `kAbortLoadGame` 會 unwind VM 後呼叫遊戲 `replay`（＝「在選單時載入存檔」的恢復路徑），進入
  `currentRoomNumber()`（＝剛設的 100）。
- **為何要 `_gfxPorts->reset()`**：abort 沒 dispose 年齡選單的對話框 window，會疊在 room 100 上。
  這正是 restore 路徑（`savegame.cpp`）清殘留 window 的同一招。
- 事件層攔截 `KEYCODE_x + KBD_CTRL + KBD_ALT`（在 F8 handler 之後）。原版 LSL1 SCI 無此後門，此為中文化外掛。

EGA/AGI 同理（見 `docs/40-agi-track.md`）：攔截 Ctrl+Alt+X，room 6 → `closeWindow` + `exitAllLogics`
+ `cycleInnerLoopInactive` + `newRoom(11)`（比照 AGI restore 從 inner loop 直接換場）。

## 8. 沿用到其他 SCI/AGI 遊戲的通則

1. **要「跳過」一道 gate/防拷，優先想「直接換到門後房間」，別逐題模擬作答**——用引擎內建的
   除錯器換場 / restore 恢復機制（SCI `setRoomNumber`+`kAbortLoadGame`+`_gfxPorts->reset()`；
   AGI `newRoom`+`exitAllLogics`+`closeWindow`+`cycleInnerLoopInactive`）。第一性原理省下大量特例。
2. **若真要逐題自動作答**（保留片頭的「一次通過永久免答」）：問答式防拷幾乎都把正解存在某個 script local
   ——先 dump 題庫資源看格式（常是「首字元/首欄=答案」），再用 `Box()` probe 對照 room script 的 locals 找哪一格；
   輸入方式看畫面提示（TAB 選單 vs 字母 vs 直接按鍵）別假設統一；合成鍵在 `getScummVMEvent` 輪詢前注入以優先於玩家；
   判定用存檔＋旗標檔雙保險。**笑話題（任意答案、`local[4]=0`）要偵測問句結尾 `?` 按 'a' 過關，否則卡死。**
