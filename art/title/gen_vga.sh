#!/bin/bash
set -e
F=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc
W=640; H=400
TXT="幻想空間"
PS=78
YOFF=14        # North gravity y offset -> upper band above warning box
cd /w/art/title/tmp

# 1) text alpha mask
convert -size ${W}x${H} xc:black -font "$F" -pointsize $PS \
  -fill white -gravity North -annotate +0+${YOFF} "$TXT" vmask.png

# 2) warm neon gradient: top orange -> mid pink -> bottom magenta
convert -size ${W}x${H} gradient:'#ffb14a-#ff2f8f' vgrad.png

# 3) colored text
convert vgrad.png vmask.png -alpha off -compose CopyOpacity -composite vcol.png

# 4) black outline (dilate)
convert vmask.png -morphology Dilate Disk:5 vdil.png
convert -size ${W}x${H} xc:'#1a0018' vdil.png -alpha off -compose CopyOpacity -composite voutline.png

# 5) outer neon GLOW: dilate more, bright pink, heavy blur, semi-transparent
convert vmask.png -morphology Dilate Disk:9 vglowmask.png
convert -size ${W}x${H} xc:'#ff3ea5' vglowmask.png -alpha off -compose CopyOpacity -composite vglow0.png
convert vglow0.png -channel A -blur 0x9 -evaluate multiply 0.85 +channel vglow.png

# 6) drop shadow
convert voutline.png -alpha extract -blur 0x2 vsh_a.png
convert -size ${W}x${H} xc:'#000000' vsh_a.png -alpha off -compose CopyOpacity -composite vshadow0.png
convert vshadow0.png -channel A -evaluate multiply 0.7 +channel -page +5+6 -background none -flatten vshadow.png

# 7) inner highlight ring
convert vmask.png -morphology Dilate Disk:2 vring_m.png
convert -size ${W}x${H} xc:'#ffd08a' vring_m.png -alpha off -compose CopyOpacity -composite vring.png

# 8) compose: glow -> shadow -> outline -> ring -> fill
convert -size ${W}x${H} xc:none \
  vglow.png -composite \
  vshadow.png -composite \
  voutline.png -composite \
  vring.png -composite \
  vcol.png -composite \
  /w/art/title/title-cht-vga.png

echo "VGA done"
