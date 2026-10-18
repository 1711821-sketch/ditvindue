#!/usr/bin/env bash
# Builds the "squeegee art" video: DITVINDUE pulled out of foam over Dino's own footage.
# Usage: bash build-squeegee-art.sh <source-dir> <cards-dir> <work-dir>
set -euo pipefail

SRC="$1"; CARDS="$2"; WORK="$3"
OUTDIR="billeder/video"
DUR=9.6; FPS=30; N=$(awk "BEGIN{print int($DUR*$FPS)}")
GRADE="eq=contrast=1.08:saturation=1.15:gamma=1.02,colorbalance=rs=.03:bs=-.03:rm=.02:bm=-.02,unsharp=5:5:0.6"
ENC=(-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -an)
mkdir -p "$WORK/bg" "$WORK/frames" "$OUTDIR"

# 1) background: clear window with Dino working (from inside)
ffmpeg -v error -y -ss 17.0 -t "$DUR" -i "$SRC/IMG_0553.MOV" -vf "fps=$FPS,scale=1080:1920,$GRADE" -q:v 2 "$WORK/bg/bg_%04d.jpg"

# 2) foam + letters + squeegee, frame by frame
node render-squeegee-art.js "$WORK/bg" "$WORK/frames" "$N"

# 3) assemble with a slow push-in while the word holds (5.2–6.6 s), easing back out during the final clear
Z="if(lt(t,5.2),1,if(lt(t,6.6),1+0.1*(t-5.2)/1.4,1.1-0.1*min((t-6.6)/1.2,1)))"
ffmpeg -v error -y -framerate $FPS -i "$WORK/frames/f_%04d.jpg" \
  -vf "scale=w='trunc(1080*($Z)/2)*2':h='trunc(1920*($Z)/2)*2':eval=frame,crop=1080:1920,setsar=1" \
  "${ENC[@]}" "$WORK/art.mp4"

# 4) end card with zoom settle, joined with a slide-up
ffmpeg -v error -y -loop 1 -t 2.8 -i "$CARDS/card_end.png" \
  -vf "fps=30,scale=w='trunc(1080*(1+0.06*(1-min(t/0.8,1)))/2)*2':h='trunc(1920*(1+0.06*(1-min(t/0.8,1)))/2)*2':eval=frame,crop=1080:1920,format=yuv420p" \
  -t 2.8 "${ENC[@]}" "$WORK/end.mp4"
OFF=$(awk "BEGIN{print $DUR-0.4}")
ffmpeg -v error -y -i "$WORK/art.mp4" -i "$WORK/end.mp4" \
  -filter_complex "[0:v]settb=AVTB[a];[1:v]settb=AVTB[b];[a][b]xfade=transition=slideup:duration=0.4:offset=$OFF" \
  "${ENC[@]}" -movflags +faststart "$OUTDIR/ditvindue-squeegee-art.mp4"

# 5) web version + poster (poster = the finished word)
ffmpeg -v error -y -i "$OUTDIR/ditvindue-squeegee-art.mp4" -vf "scale=540:960" -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-squeegee-art-web.mp4"
ffmpeg -v error -y -ss 5.6 -i "$OUTDIR/ditvindue-squeegee-art.mp4" -frames:v 1 -vf "scale=540:960" -q:v 3 "$OUTDIR/ditvindue-squeegee-art-poster.jpg"
ls -la "$OUTDIR" | grep squeegee
