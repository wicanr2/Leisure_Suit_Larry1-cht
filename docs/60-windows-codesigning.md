# Windows 版防毒誤報 · 程式碼簽章

> 對應 issue #1「Win10/11 出現 zip 檔偵測到病毒 Cobalt Strike」。本文記錄誤報成因、已做的緩解、
> 向 Microsoft 回報的步驟，以及 SignPath Foundation（開源免費簽章）的申請與 CI 接線方式。

## 1. 問題

Windows 10/11 的 Defender 把 Windows 包裡的 `scummvm.exe` 判為 **Cobalt Strike**（C2 後門）。

## 2. 成因：這是誤報（false positive）

`scummvm.exe` 是開源模擬器 **ScummVM**（scummvm.org，GPLv3）加上本專案中文化修改，用 mingw-w64
交叉編譯而成。判定為誤報的證據：

- **無任何 C2／注入 API**：`objdump -x` 檢查無 `VirtualAllocEx` / `CreateRemoteThread` /
  `WriteProcessMemory` / `WinInet`/`InternetOpen` / `WSASocket`——沒有 Cobalt Strike beacon 的實際
  行為指紋（只有 `VirtualProtect`，C++/SDL 正常使用）。
- **未加殼**：`objdump -h` 無 UPX/packer 段。
- **有正規版本資源**：內含 ScummVM 官方 version info（CompanyName `scummvm.org`）。

真因是 **未簽章 + 低知名度（low prevalence）執行檔的啟發式／ML 誤判**——Defender 對「從沒見過、
又沒簽章」的 PE 特別敏感，常升級成一個具名威脅。mingw 交叉編譯的開源執行檔尤其容易中。

### 診斷指令（重現用）
```bash
# 取出 exe
unzip -p dist-all/幻想空間-VGA-windows-x64.zip scummvm.exe > /tmp/scummvm.exe
# 檢查有無 C2/注入 API（應為空）
docker run --rm -v /tmp:/t qfg1-mingw bash -c \
  "x86_64-w64-mingw32-objdump -x /t/scummvm.exe | grep -iE 'VirtualAllocEx|CreateRemoteThread|WriteProcessMemory|WinInet|WSASocket'"
# 檢查有無加殼（應無 UPX 段）
docker run --rm -v /tmp:/t qfg1-mingw bash -c \
  "x86_64-w64-mingw32-objdump -h /t/scummvm.exe | grep -iE 'UPX|packed'"
sha256sum /tmp/scummvm.exe
```

## 3. 兩條解法

| 解法 | 效果 | 成本 |
|---|---|---|
| **向 Microsoft 回報誤報** | 通過分析後白名單該檔 hash（Defender） | 免費，約 24–72h |
| **程式碼簽章（SignPath OSS）** | 具名發行者 + 累積信譽，根治此類啟發式誤判 | 免費（開源方案），需申請核准 |

> 不要浪費時間在：**自簽憑證**（發行者不受信任、無效）、**Sigstore/cosign**（供應鏈簽章，
> Windows SmartScreen/Defender 不認）。

## 4. 向 Microsoft 回報誤報

1. 從 zip 取出被判的 `scummvm.exe`（EGA/VGA 兩版都送更保險）。
2. 開 https://www.microsoft.com/en-us/wdsi/filesubmission ，登入 Microsoft 帳號。
3. 帳號類型選 **Software developer**。
4. 上傳 `scummvm.exe`（或整包 zip）。
5. 表單：
   - What do you believe this file is? → **Incorrectly detected (false positive)**
   - Detection name → Defender 顯示的（如 `Trojan:Win64/CobaltStrike.xxx`，不確定填 `Cobalt Strike`）
   - Detected by → **Microsoft Defender Antivirus**
6. Additional information 貼：

   > This file is `scummvm.exe`, a build of the open-source ScummVM engine
   > (https://scummvm.org, GPLv3) with a Traditional-Chinese fan-translation patch,
   > cross-compiled with mingw-w64. It contains no C2 or code-injection APIs and is not
   > packed. Full source and a reproducible GitHub Actions build are public at
   > https://github.com/wicanr2/Leisure_Suit_Larry1-cht . This is a heuristic false
   > positive on an unsigned, low-prevalence binary. Please re-analyze and whitelist.

7. 送出取得 submission ID，可回查狀態。
8. （選配）順手傳 VirusTotal（https://www.virustotal.com ）看報的引擎數，佐證是 FP。

## 5. SignPath Foundation（開源免費簽章）

### 前置（已完成）
- Windows 版已有**可審核、可重現的 CI 建置**：`.github/workflows/build-windows.yml`
  （pinned mingw-w64 + `apply_patches.sh` clone pinned commit 套 patch → 產
  `scummvm.exe` + DLL + `SHA256SUMS` artifact）。SignPath 要求建置可追溯，這步是必要前置。

### 申請
- 入口：https://signpath.org/apply （或 email hello@signpath.io）。
- 審核條件：OSI 開源授權（引擎 GPLv3 ✅）、非商業免費（✅）、建置可追溯（CI ✅）、
  專案有實質內容（較主觀）、無惡意程式。
- 申請內容見本 repo issue 討論／README；要簽的是 Windows 的 `scummvm.exe`。

### 核准後接線（CI 自動簽）
1. 在 repo **Settings → Secrets** 加 `SIGNPATH_API_TOKEN`。
2. 解除 `build-windows.yml` 檔尾 `sign-windows` job 的註解，填入 SignPath 給的
   `organization-id` / `project-slug` / `signing-policy-slug`。
3. 之後每次 `workflow_dispatch` 或推 `v*-windows` tag，CI 會把 `scummvm.exe` 送 SignPath 簽，
   回傳已簽章檔（artifact `...-signed`）。
4. 本機 `tools/package_windows.sh` 改用「已簽章的 exe」組完整包，即根治誤報。

文件：https://about.signpath.io/documentation/github-actions

## 6. 參考 hash（目前本機 mingw 版）

| 版本 | `scummvm.exe` SHA-256 |
|---|---|
| EGA | `b4ae775ae926bd899f833ed786b5c5e4f7aef646fc3359ccda8511dee3914746` |
| VGA | `10eb3cc6c1d2d5787f2507c78b20ca1db12e9e8760d21effa637d0fe8ae70342` |
