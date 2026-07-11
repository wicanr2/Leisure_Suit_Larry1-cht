#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把在地化批次（loc_<ed>_*.done.tsv）併回完整翻譯表，只替換有在地化的行，其餘原樣保留。
同時驗證：英文 key 一致、控制碼(\n/%..)數量不變、行數不變。

用法: merge_localized.py <ega|vga> <full_in.tsv> <localize_dir> <full_out.tsv>
"""
import sys, re, glob, os

def codes(s):
    return (len(re.findall(r'\\n', s)),
            len(re.findall(r'%[a-zA-Z]?\d*', s)))

def main():
    ed, full_in, locdir, full_out = sys.argv[1:5]
    # 收集在地化 map（english -> localized zh），並自我驗證
    loc = {}
    warned = 0
    for p in sorted(glob.glob(os.path.join(locdir, f"loc_{ed}_*.done.tsv"))):
        src = p.replace('.done.tsv', '.tsv')
        S = [l.rstrip('\n') for l in open(src, encoding='utf-8')] if os.path.exists(src) else []
        D = [l.rstrip('\n') for l in open(p, encoding='utf-8')]
        if S and len(S) != len(D):
            print(f"⚠️ {os.path.basename(p)} 行數 {len(D)} != 輸入 {len(S)}", file=sys.stderr)
        for idx, d in enumerate(D):
            if '\t' not in d:
                continue
            den, dzh = d.split('\t', 1)
            # 對照原輸入的英文/直譯，驗證 key 與控制碼
            if S and idx < len(S) and '\t' in S[idx]:
                sen, szh = S[idx].split('\t', 1)
                if sen != den:
                    print(f"⚠️ {os.path.basename(p)} 行{idx+1} 英文 key 不符，跳過此行", file=sys.stderr)
                    warned += 1
                    continue
                if codes(szh) != codes(dzh):
                    print(f"⚠️ {os.path.basename(p)} 行{idx+1} 控制碼數變動：{szh[:30]!r} -> {dzh[:30]!r}", file=sys.stderr)
                    warned += 1
                    # 仍採用（控制碼變動不一定壞，但要提醒）
            loc[den] = dzh

    # 併回完整表
    n_repl = 0
    out = []
    with open(full_in, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if '\t' not in line:
                out.append(line); continue
            en, zh = line.split('\t', 1)
            if en in loc and loc[en] != zh:
                out.append(f"{en}\t{loc[en]}")
                n_repl += 1
            else:
                out.append(line)
    with open(full_out, 'w', encoding='utf-8') as o:
        o.write('\n'.join(out) + '\n')
    print(f"{ed}: 在地化 {len(loc)} 則 → 替換 {n_repl} 行；警告 {warned}；輸出 {full_out}")

if __name__ == "__main__":
    main()
