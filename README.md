# 幻想空間 — Leisure Suit Larry 1 繁體中文化

> **Leisure Suit Larry in the Land of the Lounge Lizards**（勞瑞任務 / 幻想空間）
> Sierra On-Line 1987（AGI/EGA）＋ 1991（SCI1/VGA）｜ ScummVM 繁體中文化 patch

當年那個要你先答對一堆成人常識題才准進門的遊戲，那個穿著一身廉價白西裝、頂著金項鍊、一心想在賭城 Lost Wages 脫離單身的 Larry Laffer——這個 repo 要把它完整地說回中文。

本專案為 **ScummVM patch 形式**的繁體中文化，同時涵蓋兩個歷史版本：

| 版本 | 年份 | 引擎 | 畫面 |
|---|---|---|---|
| EGA 版 | 1987 | AGI 2.440 | 16 色 |
| VGA 版 | 1991 | SCI1 | 256 色 |

> 🚧 **開發中**。目前狀態、里程碑與技術路線見 [`docs/00-overall-plan.md`](docs/00-overall-plan.md)。

---

## 文件索引

- 📋 [整體規劃書](docs/00-overall-plan.md) — 版本鑑定、雙軌技術路線、里程碑、風險
- 📖 遊戲介紹與手冊要點 — （撰寫中，將補齊當年中文資料 + walkthrough）
- 🔧 技術細節 — 雙引擎 CJK patch、content-keyed 翻譯、字型烘製（撰寫中）

## 交付政策

- GitHub repo 只放 **patch-only** 版本（引擎 patch + 字型 + 翻譯表 + 工具鏈）。
- 完整遊戲包（含原始資源）**不上傳**，另放 `dist-all/`。
- 打包平台：Windows / macOS / AppImage。

## 授權

中文化 patch 依 ScummVM 之 GPL 授權。原始遊戲版權屬 Sierra / Activision，本專案不含任何原始遊戲資源。
