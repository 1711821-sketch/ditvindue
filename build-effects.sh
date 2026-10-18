#!/usr/bin/env bash
# Builds the effect videos (before/after wipe + action clip) from raw iPhone clips.
# Usage: bash build-effects.sh <source-dir> <overlay-dir> <work-dir>
set -euo pipefail

SRC="$1"; OV="$2"; WORK="$3"
OUTDIR="billeder/video"
mkdir -p "$WORK" "$OUTDIR"

GRADE="eq=contrast=1.07:saturation=1.2:gamma=1.03,colorbalance=rs=.04:bs=-.04:rm=.02:bm=-.03,unsharp=5:5:0.5"
GLOW="format=gbrp,split[gA][gB];[gB]gblur=sigma=28[gG];[gA][gG]blend=all_mode=screen:all_opacity=0.26,format=yuv420p"
ENC=(-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -an)

dur_of() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

# ---------- 1) Before/after wipe, 4:5 (1080x1350) ----------
BA_CROP="scale=1080:1920,crop=1080:1350:0:300,setsar=1"
WIPE=0.9

ffmpeg -v error -y -ss 0.5 -t 2.6 -i "$SRC/IMG_0553.MOV" -i "$OV/ov_before.png" \
  -filter_complex "[0:v]fps=30,$BA_CROP,$GRADE,vignette=PI/5[v];[v][1:v]overlay=0:0" "${ENC[@]}" "$WORK/ba1.mp4"
ffmpeg -v error -y -ss 22.0 -t 4.5 -i "$SRC/IMG_0553.MOV" -loop 1 -t 4.5 -i "$OV/ov_after.png" \
  -filter_complex "[0:v]fps=30,$BA_CROP,$GRADE,vignette=PI/5[v];[1:v]format=rgba,fade=in:st=0.6:d=0.3:alpha=1[o];[v][o]overlay=0:0:shortest=1" "${ENC[@]}" "$WORK/ba2.mp4"

OFF=$(awk "BEGIN{print 2.6-$WIPE}")
END=$(awk "BEGIN{print $OFF+$WIPE}")
ffmpeg -v error -y -i "$WORK/ba1.mp4" -i "$WORK/ba2.mp4" -loop 1 -i "$OV/ov_bar.png" \
  -filter_complex "[0:v]settb=AVTB[a];[1:v]settb=AVTB[b];[a][b]xfade=transition=wipedown:duration=$WIPE:offset=$OFF[x];[2:v]format=rgba[bar];[x][bar]overlay=x=0:y='(t-$OFF)/$WIPE*1350-45':enable='between(t,$OFF,$END)':shortest=1" \
  "${ENC[@]}" -movflags +faststart "$OUTDIR/ditvindue-foer-efter.mp4"
echo "built foer-efter ($(dur_of "$OUTDIR/ditvindue-foer-efter.mp4")s)"

# ---------- 2) Action clip, 9:16 (1080x1920) ----------
V="scale=1080:1920,setsar=1"
# punch-in zoom: Z grows from 1 to $2 over $3 seconds, center crop
punch() { echo "scale=w='trunc(1080*(1+($1-1)*min(t/$2,1))/2)*2':h='trunc(1920*(1+($1-1)*min(t/$2,1))/2)*2':eval=frame,crop=1080:1920"; }

# a1 hook: soap, punch-in
ffmpeg -v error -y -ss 0.0 -t 1.6 -i "$SRC/IMG_0558.MOV" -loop 1 -t 1.6 -i "$OV/ov_se.png" \
  -filter_complex "[0:v]fps=30,$V,$(punch 1.18 1.6),$GRADE,$GLOW[v];[1:v]format=rgba,fade=in:st=0.1:d=0.25:alpha=1[o];[v][o]overlay=0:0:shortest=1" "${ENC[@]}" "$WORK/a1.mp4"
# a2 smooth slow-motion squeegee stroke (motion-interpolated 0.5x)
ffmpeg -v error -y -ss 5.5 -t 1.25 -i "$SRC/IMG_0550.MOV" \
  -vf "$V,minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=2*PTS,fps=30,$GRADE,$GLOW" "${ENC[@]}" "$WORK/a2.mp4"
# a3 boomerang stroke
ffmpeg -v error -y -ss 0.25 -t 2.0 -i "$SRC/IMG_0549.MOV" \
  -filter_complex "[0:v]setpts=PTS/1.3,fps=30,$V,$GRADE,$GLOW,split[f][r0];[r0]reverse[r];[f][r]concat=n=2:v=1" "${ENC[@]}" "$WORK/a3.mp4"
# a4 fast timelapse from foam to clear, slow push-in
ffmpeg -v error -y -ss 2.0 -t 28.0 -i "$SRC/IMG_0553.MOV" \
  -vf "setpts=(PTS-STARTPTS)/6,fps=30,$V,$(punch 1.10 4.6),$GRADE,$GLOW" "${ENC[@]}" "$WORK/a4.mp4"
# a5 Dino to camera, punch-in + name
ffmpeg -v error -y -ss 17.6 -t 2.5 -i "$SRC/IMG_0550.MOV" -loop 1 -t 2.5 -i "$OV/ov_name.png" \
  -filter_complex "[0:v]fps=30,$V,$(punch 1.12 2.5),$GRADE,$GLOW[v];[1:v]format=rgba,fade=in:st=0.4:d=0.3:alpha=1[o];[v][o]overlay=0:0:shortest=1" "${ENC[@]}" "$WORK/a5.mp4"
# a6 end card
ffmpeg -v error -y -ss 20.0 -i "$SRC/IMG_0550.MOV" -frames:v 1 -vf "$V,$GRADE" "$WORK/a_endbg.png"
ffmpeg -v error -y -loop 1 -t 2.8 -i "$WORK/a_endbg.png" -loop 1 -t 2.8 -i "$OV/ov_end.png" \
  -filter_complex "[0:v]boxblur=24:2,fps=30,setsar=1[b];[b][1:v]overlay=0:0" -t 2.8 "${ENC[@]}" "$WORK/a6.mp4"

# chain with transitions
D1=$(dur_of "$WORK/a1.mp4"); D2=$(dur_of "$WORK/a2.mp4"); D3=$(dur_of "$WORK/a3.mp4")
D4=$(dur_of "$WORK/a4.mp4"); D5=$(dur_of "$WORK/a5.mp4")
T1=0.3; T2=0.35; T3=0.5; T4=0.3; T5=0.5
O1=$(awk "BEGIN{print $D1-$T1}")
O2=$(awk "BEGIN{print $O1+$D2-$T2}")
O3=$(awk "BEGIN{print $O2+$D3-$T3}")
O4=$(awk "BEGIN{print $O3+$D4-$T4}")
O5=$(awk "BEGIN{print $O4+$D5-$T5}")
ffmpeg -v error -y -i "$WORK/a1.mp4" -i "$WORK/a2.mp4" -i "$WORK/a3.mp4" -i "$WORK/a4.mp4" -i "$WORK/a5.mp4" -i "$WORK/a6.mp4" \
  -filter_complex "\
[0:v]settb=AVTB[v0];[1:v]settb=AVTB[v1];[2:v]settb=AVTB[v2];[3:v]settb=AVTB[v3];[4:v]settb=AVTB[v4];[5:v]settb=AVTB[v5];\
[v0][v1]xfade=transition=fadewhite:duration=$T1:offset=$O1[x1];\
[x1][v2]xfade=transition=slideup:duration=$T2:offset=$O2[x2];\
[x2][v3]xfade=transition=circleopen:duration=$T3:offset=$O3[x3];\
[x3][v4]xfade=transition=fadewhite:duration=$T4:offset=$O4[x4];\
[x4][v5]xfade=transition=zoomin:duration=$T5:offset=$O5" \
  "${ENC[@]}" -movflags +faststart "$OUTDIR/ditvindue-action.mp4"
echo "built action ($(dur_of "$OUTDIR/ditvindue-action.mp4")s)"

# ---------- Web versions + posters ----------
ffmpeg -v error -y -i "$OUTDIR/ditvindue-foer-efter.mp4" -vf "scale=720:900" -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-foer-efter-web.mp4"
ffmpeg -v error -y -i "$OUTDIR/ditvindue-action.mp4" -vf "scale=540:960" -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-action-web.mp4"
ffmpeg -v error -y -ss 0.3 -i "$OUTDIR/ditvindue-foer-efter.mp4" -frames:v 1 -vf "scale=720:900" -q:v 3 "$OUTDIR/ditvindue-foer-efter-poster.jpg"
ffmpeg -v error -y -ss 5.0 -i "$OUTDIR/ditvindue-action.mp4" -frames:v 1 -vf "scale=540:960" -q:v 3 "$OUTDIR/ditvindue-action-poster.jpg"

ls -la "$OUTDIR"
