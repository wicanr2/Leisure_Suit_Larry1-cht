#!/usr/bin/env bash
# 推廣影片合成（靜態圖 + fade，不用 zoompan；docker game-video 內跑，--cpus=2）。
# 用法（docker 內）: ED=ega|vga bash /make.sh
# 掛載: /shots(截圖) /music(wav) /out(輸出) /make.sh
#
# [HARD] rulebook 93：配樂用「原版遊戲音樂」，不得自產。
#   音樂用 ScummVM disk audio 從遊戲側錄 AdLib 配樂（不重編碼、無版權變造）：
#     SDL_AUDIODRIVER=disk scummvm --music-driver=adlib --music-volume=255 \
#        --render-mode=ega lsl1     # EGA → sdlaudio.raw
#     （VGA 同法跑 lsl1sci）；再 ffmpeg -f s16le -ar 22050 -ac 2 轉 wav → /music/ega.wav、vga.wav
#   影片配原版音樂 → 只進 dist-all（gitignore），公開散布前須注意 Sierra 著作權。
set -eu
ED="${ED:?需 ED=ega 或 vga}"
W=1280; H=720; FPS=25; TMP=/tmp/c; mkdir -p "$TMP" /out
FB=/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc
FR=/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc

# ===== 每版獨立 theme =====
if [ "$ED" = "ega" ]; then
  BG_D='#0a0a2a'; BG_L='#1a0a3a'; ACCENT='#00e0e0'; ACC2='#ff3ea5'; TEXT='#f2f2ff'
  TITLE_ZH='幻想空間'; TITLE_EN='Leisure Suit Larry (1987 EGA)'; SUB='霓虹賭城的中年魯蛇 · 台式在地化全程繁中'
  MUSIC=/music/ega.wav
else
  BG_D='#1a1005'; BG_L='#3a2410'; ACCENT='#ffb020'; ACC2='#e05010'; TEXT='#fff4e0'
  TITLE_ZH='幻想空間'; TITLE_EN='Leisure Suit Larry (1991 VGA)'; SUB='256 色重製版 · 台式在地化全程繁中'
  MUSIC=/music/vga.wav
fi

# ---- 卡片函式 ----
card(){ # $1 out $2 中標 $3 英標 $4 副標
  convert -size ${W}x${H} "radial-gradient:${BG_L}-${BG_D}" -font "$FB" -gravity center \
    -fill "$ACC2" -pointsize 108 -annotate +4+4 "$2" -fill "$ACCENT" -pointsize 108 -annotate +0+0 "$2" \
    -fill "$TEXT" -font "$FR" -pointsize 40 -annotate +0+110 "$3" \
    -fill "$ACC2" -pointsize 30 -annotate +0+180 "$4" "$1"; }
slide(){ # $1 out $2 截圖 $3 字幕
  convert -size ${W}x${H} "gradient:${BG_L}-${BG_D}" "$TMP/bg.png"
  convert "/shots/$2" -resize 760x570 -bordercolor "$ACCENT" -border 3 "$TMP/sc.png"
  convert "$TMP/bg.png" \( "$TMP/sc.png" \) -gravity north -geometry +0+30 -composite \
    -fill "#000000bb" -draw "rectangle 0,632 ${W},720" \
    -font "$FR" -fill "$TEXT" -gravity south -pointsize 34 -annotate +0+28 "$3" "$1"; }
dcard(){ # $1 out $2 中文金句 $3 場景標
  convert -size ${W}x${H} "gradient:${BG_D}-${BG_L}" -font "$FB" \
    -fill "#ffffff18" -pointsize 320 -gravity northwest -annotate +40-40 '"' \
    -fill "$TEXT" -gravity center -pointsize 52 -annotate +0-10 "$2" \
    -fill "$ACCENT" -font "$FR" -pointsize 26 -gravity south -annotate +0+50 "$3" "$1"; }
hero(){ # $1 out $2 真實遊戲內中文標題截圖 $3 副標 —— 片頭放大亮相，復古感
  # 截圖放大近全幅(保留原像素風，用 -filter point 硬放大不糊),加霓虹外框 + 下方副標帶
  convert -size ${W}x${H} "radial-gradient:${BG_L}-${BG_D}" "$TMP/hbg.png"
  convert "/hero.png" -filter point -resize 960x600 \
    -bordercolor "$ACC2" -border 2 -bordercolor "$ACCENT" -border 4 "$TMP/hsc.png"
  convert "$TMP/hbg.png" \( "$TMP/hsc.png" \) -gravity center -geometry +0-28 -composite \
    -font "$FR" -fill "$ACCENT" -gravity south -pointsize 30 -annotate +0+44 "$3" "$1"; }
render(){ # $1 png $2 mp4 $3 秒
  local FO; FO=$(awk "BEGIN{print $3-0.5}")
  ffmpeg -y -loglevel error -loop 1 -i "$1" -t "$3" -r $FPS \
    -vf "fade=t=in:st=0:d=0.5,fade=t=out:st=$FO:d=0.5,format=yuv420p" \
    -threads 2 -c:v libx264 -preset veryfast -pix_fmt yuv420p "$2"; }

# ===== 分鏡 =====
i=0; LIST="$TMP/list.txt"; : > "$LIST"
add(){ render "$1" "$TMP/s$(printf %02d $i).mp4" "$2"; echo "file '$TMP/s$(printf %02d $i).mp4'" >> "$LIST"; i=$((i+1)); }

card "$TMP/00.png" "$TITLE_ZH" "$TITLE_EN" "$SUB"; add "$TMP/00.png" 6
# 中文標題亮相（真實遊戲畫面放大，復古感）—— 需掛載 /hero.png
if [ -f /hero.png ]; then
  if [ "$ED" = ega ]; then HSUB='1987 原版經典重現 · 全程繁體中文'; else HSUB='1991 VGA 重製 · 全程繁體中文'; fi
  hero "$TMP/hero.png" _ "$HSUB"; add "$TMP/hero.png" 5
fi
# 截圖輪播（依 shots 目錄）
n=1
for f in $(ls /shots | sort); do
  case "$ED-$f" in
    *localized*|*loc*) CAP='遊戲內實機：台式在地化旁白' ;;
    *title*)   CAP='那個穿廉價白西裝、想把妹的中年魯蛇' ;;
    *age*)     CAP='先答對成人問答，才准進門' ;;
    *warning*|*sturgeon*) CAP='「本遊戲含成人劇情，兒童不宜」——這次看得懂了' ;;
    *reject*)  CAP='太年輕？回家找個大人吧' ;;
    *bar*|*interior*) CAP='老左酒吧——你見過最骯髒下流的酒吧' ;;
    *)         CAP='全程繁體中文化' ;;
  esac
  cp "/shots/$f" "$TMP/shot_$f"
  slide "$TMP/sl$n.png" "$f" "$CAP"; add "$TMP/sl$n.png" 5; n=$((n+1))
done
# ===== 台式在地化金句（招牌賣點）=====
card "$TMP/loc.png" '台式在地化' '不只翻譯，是重寫成台灣人一看就笑' '色在雙關 · 笑在自嘲 · 賤在旁白'; add "$TMP/loc.png" 4
if [ "$ED" = "ega" ]; then
  dcard "$TMP/d1.png" '這身騷包白西裝是你全身最值錢的行頭——偏偏口袋比臉還乾淨。' '— 檢視賴瑞的行頭 · 自嘲魯蛇'; add "$TMP/d1.png" 5
  dcard "$TMP/d2.png" '驚傳！中年男夜闖暗巷慘遭「關切」，當場領便當。' '— 死法旁白 · 報紙社會版標題腔'; add "$TMP/d2.png" 5
  dcard "$TMP/d3.png" '都領便當了還在碎念？歹勢啦，坐乎穩，好好享受這趟單程之旅。' '— 死後吐槽 · 台語提味'; add "$TMP/d3.png" 5
else
  dcard "$TMP/d1.png" '齁！你這一身味，是路邊那根被狗做記號做十年的消防栓吧？' '— 酒客嗆聲'; add "$TMP/d1.png" 5
  dcard "$TMP/d2.png" '而且你那口氣——是把整攤臭豆腐吞下去了是不是啦！' '— 你聞聞自己'; add "$TMP/d2.png" 5
  dcard "$TMP/d3.png" '看到雜誌封面那對「哈密瓜」，蘋果頓時自卑了起來。' '— 諧音雙關 · 點到為止'; add "$TMP/d3.png" 5
fi
card "$TMP/99.png" "$TITLE_ZH" "$TITLE_EN" "繁體中文化 · ScummVM patch · github.com/wicanr2/Leisure_Suit_Larry1-cht"; add "$TMP/99.png" 6

# ===== concat + 配樂 =====
ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -threads 2 -c:v libx264 -preset veryfast -pix_fmt yuv420p "$TMP/silent.mp4"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$TMP/silent.mp4"); FO=$(awk "BEGIN{print $DUR-3}")
# 配樂循環鋪滿全片（影片可能比單段配樂長，aloop 無限循環後 atrim 到影片長度，避免 -shortest 砍掉結尾卡）
ffmpeg -y -loglevel error -i "$TMP/silent.mp4" -i "$MUSIC" \
  -filter_complex "[1:a]aloop=loop=-1:size=2000000000,atrim=0:$DUR,afade=t=in:st=0:d=2,afade=t=out:st=$FO:d=3,asetpts=N/SR/TB[a]" \
  -map 0:v -map "[a]" -threads 2 -c:v libx264 -preset veryfast -c:a aac -b:a 192k -movflags +faststart \
  "/out/幻想空間-${ED}-promo.mp4"
echo "完成: /out/幻想空間-${ED}-promo.mp4 ($DUR s)"
