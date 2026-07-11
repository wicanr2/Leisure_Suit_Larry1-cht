#!/usr/bin/env bash
# 產生「直譯 → 台式在地化」對照視覺圖（圖文並茂用）。docker game-video 內跑。
# 掛載: /out。輸出 /out/loc-compare-ega.png、/out/loc-compare-vga.png
set -eu
W=1280
FB=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc
FR=/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc

# 一列對照：$1 out $2 情境 $3 直譯 $4 台式 $5 手法標
row(){ convert -size ${W}x150 xc:'#141420' \
  -font "$FB" -fill '#ffb020' -pointsize 26 -gravity northwest -annotate +30+18 "$2" \
  -font "$FR" -fill '#8890a0' -pointsize 27 -gravity northwest -annotate +30+58 "直譯　$3" \
  -font "$FB" -fill '#f2f2ff' -pointsize 29 -gravity northwest -annotate +30+98 "台式　$4" \
  -font "$FR" -fill '#ff6ba8' -pointsize 20 -gravity northeast -annotate +30+20 "$5" \
  -fill '#2a2a3a' -draw "rectangle 0,148 ${W},150" "$1"; }

hdr(){ convert -size ${W}x110 "gradient:$2-$3" -font "$FB" \
  -fill white -pointsize 46 -gravity west -annotate +30+0 "$4" \
  -font "$FR" -fill '#ffe0b0' -pointsize 24 -gravity east -annotate +30+0 "同一句話，笑點差多少" "$1"; }

mk(){ # $1 ega|vga
  local T=/tmp/c_$1; mkdir -p "$T"
  if [ "$1" = ega ]; then
    hdr "$T/h.png" '#1a0a3a' '#3a1030' '台式在地化 · EGA'
    row "$T/r1.png" '賴瑞行頭' '你的豔裝套裝很時髦，但口袋空空。' '這身騷包白西裝是你全身最值錢的行頭——偏偏口袋比臉還乾淨。' '自嘲魯蛇'
    row "$T/r2.png" '暗巷橫死' '賴瑞，你什麼時候才能學會不進那些黑暗小巷！！' '驚傳！中年男夜闖暗巷慘遭「關切」，當場領便當。' '報紙社會版腔'
    row "$T/r3.png" '死後吐槽' '既然你已經死了，為什麼還在說話？' '都領便當了還在碎念？歹勢啦，坐乎穩，好好享受這趟單程之旅。' '台語提味'
    row "$T/r4.png" '諧音雙關' '（Ball Street Journal / 華爾街日報諧音）' '你抓起一本古董級的《葷經日報》，準備坐下來「好好沉思」！' '諧音·露骨留白'
  else
    hdr "$T/h.png" '#2a1005' '#3a1810' '台式在地化 · VGA'
    row "$T/r1.png" '酒客嗆聲' '呸！你聞起來像用過的消防栓！' '齁！你這一身味，是路邊那根被狗做記號做十年的消防栓吧？' 'NPC 冷回'
    row "$T/r2.png" '保險套' '你妥善丟掉你的「潤滑品」。' '你妥善處理掉你的「小雨衣」。你媽看到肯定與有榮焉。' '在地隱語'
    row "$T/r3.png" '性暗示雙關' '（em-bare-assing 拆字雙關）' '你知道那該有多丟「腚」吧！' '拆字諧音'
    row "$T/r4.png" '雜誌葷梗' '（Humongous Tetons / 大提頓山黃腔）' '看到雜誌封面那對「哈密瓜」，蘋果頓時自卑了起來。' '諧音·點到為止'
  fi
  convert -append "$T/h.png" "$T/r1.png" "$T/r2.png" "$T/r3.png" "$T/r4.png" \
    -bordercolor '#2a2a3a' -border 2 "/out/loc-compare-$1.png"
  echo "  /out/loc-compare-$1.png"
}
mk ega
mk vga
