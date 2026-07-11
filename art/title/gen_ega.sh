#!/bin/bash
set -e
F=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc
W=640; H=400
TXT="幻想空間"
PS=92          # pointsize
YOFF=246       # North gravity y offset -> lower-center band
mkdir -p /w/art/title/tmp
cd /w/art/title/tmp

# 1) text alpha mask (white text on black)
convert -size ${W}x${H} xc:black -font "$F" -pointsize $PS \
  -fill white -gravity North -annotate +0+${YOFF} "$TXT" mask.png

# 2) vertical gradient: top magenta/pink -> bottom red-orange (matches logo)
convert -size ${W}x${H} gradient:'#ff5ec8-#ff4a2a' grad.png

# 3) colored text (gradient through mask)
convert grad.png mask.png -alpha off -compose CopyOpacity -composite coltext.png

# 4) thick black outline: dilate mask, paint black
convert mask.png -morphology Dilate Disk:6 dil.png
convert -size ${W}x${H} xc:black dil.png -alpha off -compose CopyOpacity -composite outline.png

# 4b) a thin inner highlight ring (bright pink) between outline and fill for neon
convert mask.png -morphology Dilate Disk:2 dil2.png
convert -size ${W}x${H} xc:'#ff9ad6' dil2.png -alpha off -compose CopyOpacity -composite ring.png

# 5) drop shadow: outline shape offset + blur, dark navy/black
convert outline.png -channel A -blur 0x3 +channel \
  -background none -alpha set -fill '#00000090' -colorize 0 \
  shadowsh.png
# make shadow solid dark using outline alpha
convert outline.png -alpha extract -blur 0x2 sh_a.png
convert -size ${W}x${H} xc:'#101038' sh_a.png -alpha off -compose CopyOpacity -composite shadow0.png
convert shadow0.png -page +6+7 -background none -flatten shadow.png

# 6) compose: shadow -> outline -> ring -> colored fill
convert -size ${W}x${H} xc:none \
  shadow.png -composite \
  outline.png -composite \
  ring.png -composite \
  coltext.png -composite \
  /w/art/title/title-cht-ega.png

echo "EGA done"
