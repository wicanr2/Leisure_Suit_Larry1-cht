#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把翻譯表切成「台式在地化」批次。只挑有喜劇/散文價值的句子，跳過：
  - 控制碼 / 英文==中文（未翻或 passthrough）
  - 雙語問答行（含 "\n  a." 或 " a. " 選項格式，或行內已附英文對照 → 防拷問答，不可動）
  - 過短（<4 中文字）純機械字串
輸出 batches/loc_<ed>_<NN>.tsv：每行 = 英文原文 <TAB> 現行中文譯文（給 subagent 當在地化底稿）。

用法: prep_localize_batches.py <ega|vga> <infile.tsv> <outdir> [--size 120]
"""
import sys, argparse, os, re

CJK = re.compile(r'[一-鿿]')
# 雙語問答特徵：多選項 a./b./c./d.（EGA），或行內同時有中文與大段英文對照
QUIZ = re.compile(r'(\\n\s*[a-d]\.|\n\s*[a-d]\.|\s[a-d]\.\s)')

def is_localizable(en, zh):
    if zh == en:                       # 未翻/控制碼/passthrough
        return False
    if not CJK.search(zh):             # 中文欄沒中文字 → 純符號/碼
        return False
    if len(CJK.findall(zh)) < 4:       # 太短的機械字串（如「開門。」）先跳過，降風險
        return False
    if en.startswith('%') or en.startswith('\\'):  # 控制碼開頭
        return False
    if QUIZ.search(en) or QUIZ.search(zh):         # 防拷問答，保留原樣
        return False
    # 行內已做中英雙語（中文後接大量英文原文）→ 問答殘留，跳過
    if CJK.search(zh) and re.search(r'[A-Za-z]{20,}', zh):
        return False
    return True

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("edition"); ap.add_argument("infile"); ap.add_argument("outdir")
    ap.add_argument("--size", type=int, default=120)
    a = ap.parse_args()
    os.makedirs(a.outdir, exist_ok=True)

    rows = []
    with open(a.infile, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "\t" not in line:
                continue
            en, zh = line.split("\t", 1)
            if is_localizable(en, zh):
                rows.append((en, zh))

    n = len(rows)
    nb = (n + a.size - 1) // a.size
    for i in range(nb):
        chunk = rows[i*a.size:(i+1)*a.size]
        p = os.path.join(a.outdir, f"loc_{a.edition}_{i+1:02d}.tsv")
        with open(p, "w", encoding="utf-8") as o:
            for en, zh in chunk:
                o.write(f"{en}\t{zh}\n")
    print(f"{a.edition}: 可在地化 {n} 則 → {nb} 批（每批 {a.size}）於 {a.outdir}")

if __name__ == "__main__":
    main()
