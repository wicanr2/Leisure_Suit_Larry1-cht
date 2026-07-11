import sys, os, re, glob
# 從 dump 出的 script.* 抽 null 結尾可讀字串，篩「像人話的英文句子」
def runs(data):
    out=[]; cur=bytearray()
    for b in data:
        if 32<=b<127:
            cur.append(b)
        else:
            if b==0 and cur:
                out.append(cur.decode('latin1'))
            cur=bytearray()
    return out

def looks_prose(s):
    s=s.strip()
    if len(s)<4: return False
    # 需含空格或句末標點(排除單一 selector 名)
    letters=sum(c.isalpha() for c in s)
    if letters < 3: return False
    if letters/len(s) < 0.5: return False
    has_space = ' ' in s
    has_punct = s[-1] in '.!?"'
    # 至少一個小寫(排除全大寫的常數/檔名)
    has_lower = any(c.islower() for c in s)
    if not (has_space or has_punct): return False
    if not has_lower: return False
    # 排除明顯非文案(路徑/檔名/版本)
    if re.search(r'\.(fnt|drv|exe|bat|hlp|scr|txt|000|001|002|map|cfg)\b', s, re.I): return False
    if s.startswith('%') and len(s)<8: return False
    return True

seen=set(); res=[]
for f in sorted(glob.glob('out/dump_vga/script.*')):
    data=open(f,'rb').read()[2:]  # skip 2-byte patch header
    for s in runs(data):
        s=s.replace('\r\n',' ').replace('\r',' ').replace('\n',' ')
        if looks_prose(s) and s not in seen:
            seen.add(s); res.append(s)
print(f"# script 內候選 prose 字串: {len(res)}")
open('/tmp/script_strings.txt','w').write('\n'.join(res))
