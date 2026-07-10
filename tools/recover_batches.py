#!/usr/bin/env python3
"""校正 batch 譯文輸出的常見格式錯誤（subagent 有時加行號前綴/多 tab/漏行），
用 source batch 的精確 key 對齊，產出乾淨的 <english>\t<chinese>。

作法：對每個 source key（順序），在 output 中找到「去掉行號前綴後、第一欄 strip 等於該 key」的行，
取其最後一欄當中文。輸出 batch/bNN.fix.tsv，並回報每批覆蓋率（有中譯且≠英文原文的比例）。
"""
import glob, os, re, sys

def clean_line(l):
    l = l.rstrip('\n')
    # 去掉行號前綴 "12\t" 或 "12. " 或 "12 "
    l = re.sub(r'^\s*\d+[\.\)]?\t', '\t', l)  # "12\t..." → "\t..."（保留後續 tab 結構）
    l = re.sub(r'^\s*\d+[\.\)]\s+', '', l)     # "12. ..." → "..."
    return l

def load_output(path):
    """回傳 {english_strip: chinese}。容錯：去行號、取首欄為 en、末欄為 zh。"""
    m = {}
    for raw in open(path, encoding='utf-8'):
        l = clean_line(raw)
        if '\t' not in l:
            continue
        parts = l.split('\t')
        # 去掉開頭空欄（來自行號剝除）
        while parts and parts[0] == '':
            parts.pop(0)
        if len(parts) < 2:
            continue
        en = parts[0].strip()
        zh = parts[-1]
        if en:
            m[en] = zh
    return m

def main():
    # 可指定批次目錄與前綴：recover_batches.py [dir] [prefix]（預設 EGA 的 batch/b）
    bdir = sys.argv[1] if len(sys.argv) > 1 else 'translation/batch'
    prefix = sys.argv[2] if len(sys.argv) > 2 else 'b'
    rows_report = []
    for src in sorted(glob.glob(f'{bdir}/{prefix}[0-9][0-9].tsv')):
        b = os.path.basename(src)[:-4]
        out = f'{bdir}/{b}.out.tsv'
        if not os.path.exists(out):
            continue
        omap = load_output(out)
        src_keys = []
        for l in open(src, encoding='utf-8'):
            l = l.rstrip('\n')
            if '\t' in l:
                src_keys.append(l.split('\t', 1)[0])
        fixed = []
        translated = 0
        for k in src_keys:
            zh = omap.get(k.strip())
            if zh is None:
                zh = k  # 找不到 → 留英文
            else:
                if zh.strip() and zh.strip() != k.strip():
                    translated += 1
            fixed.append(f"{k}\t{zh}")
        with open(f'{bdir}/{b}.fix.tsv', 'w', encoding='utf-8') as f:
            f.write('\n'.join(fixed) + '\n')
        pct = 100 * translated // max(1, len(src_keys))
        rows_report.append((b, len(src_keys), translated, pct))
    print("批次  總數  已譯  覆蓋率")
    for b, tot, tr, pct in rows_report:
        flag = '  <=需重翻' if pct < 60 else ''
        print(f"{b}   {tot:4d}  {tr:4d}   {pct:3d}%{flag}")

if __name__ == '__main__':
    main()
