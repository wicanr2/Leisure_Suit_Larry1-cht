#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把設計師的「幻想空間」中文標題透明 PNG，烘成引擎可疊繪的 .ovl 索引點陣圖。

用法:
  build_title_overlay.py <in.png> <out.ovl> --palette ega|vga

.ovl 格式（big-endian）:
  magic  "CHTO"           (4 bytes)
  version 1               (1 byte)
  palType 0=EGA / 1=VGA   (1 byte)
  origin_x, origin_y      (u16, u16)  非透明像素外接框左上角
  width,   height         (u16, u16)  外接框尺寸
  pixels  width*height    每 byte 一像素：0xFF=透明，否則調色盤索引

EGA：量化到標準 16 色 EGA 調色盤（索引 0-15），對齊 ScummVM AGI hi-res(640x400) display buffer。
VGA：量化到 ScummVM SCI 內建 EGA/VGA 常用色（此工具先支援輸出 RGB 供 SCI 端自行 map；預設 ega）。
"""
import sys, struct, argparse
from PIL import Image

# 標準 EGA 16 色（ScummVM AGI 使用）
EGA = [
    (0x00,0x00,0x00),(0x00,0x00,0xAA),(0x00,0xAA,0x00),(0x00,0xAA,0xAA),
    (0xAA,0x00,0x00),(0xAA,0x00,0xAA),(0xAA,0x55,0x00),(0xAA,0xAA,0xAA),
    (0x55,0x55,0x55),(0x55,0x55,0xFF),(0x55,0xFF,0x55),(0x55,0xFF,0xFF),
    (0xFF,0x55,0x55),(0xFF,0x55,0xFF),(0xFF,0xFF,0x55),(0xFF,0xFF,0xFF),
]

def nearest(pal, r, g, b):
    best, bi = 1<<30, 0
    for i,(pr,pg,pb) in enumerate(pal):
        d = (pr-r)**2 + (pg-g)**2 + (pb-b)**2
        if d < best:
            best, bi = d, i
    return bi

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("infile"); ap.add_argument("outfile")
    ap.add_argument("--palette", choices=["ega","vga"], default="ega")
    ap.add_argument("--alpha-threshold", type=int, default=128)
    a = ap.parse_args()

    img = Image.open(a.infile).convert("RGBA")
    W, H = img.size
    px = img.load()
    pal = EGA
    palType = 0 if a.palette == "ega" else 1

    # 先找非透明像素外接框
    minx, miny, maxx, maxy = W, H, -1, -1
    for y in range(H):
        for x in range(W):
            if px[x,y][3] >= a.alpha_threshold:
                if x<minx: minx=x
                if y<miny: miny=y
                if x>maxx: maxx=x
                if y>maxy: maxy=y
    if maxx < 0:
        print("!! 圖內沒有非透明像素", file=sys.stderr); sys.exit(1)
    ow, oh = maxx-minx+1, maxy-miny+1

    data = bytearray()
    opaque = 0
    for y in range(miny, maxy+1):
        for x in range(minx, maxx+1):
            r,g,b,al = px[x,y]
            if al < a.alpha_threshold:
                data.append(0xFF)
            else:
                data.append(nearest(pal, r,g,b))
                opaque += 1

    with open(a.outfile, "wb") as f:
        f.write(b"CHTO")
        f.write(struct.pack("B", 1))
        f.write(struct.pack("B", palType))
        f.write(struct.pack(">HHHH", minx, miny, ow, oh))
        f.write(bytes(data))

    print(f"OK: {a.outfile}  框=({minx},{miny}) {ow}x{oh}  非透明={opaque} px  調色盤={a.palette}")

if __name__ == "__main__":
    main()
