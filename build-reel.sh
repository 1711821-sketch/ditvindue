#!/usr/bin/env bash
# Builds the DITvindue reel from raw iPhone clips.
# Usage: bash build-reel.sh <source-dir> <overlay-dir> <work-dir>
set -euo pipefail

SRC="$1"; OV="$2"; WORK="$3"
OUTDIR="billeder/video"
mkdir -p "$WORK" "$OUTDIR"

GRADE="eq=contrast=1.07:saturation=1.2:gamma=1.03,colorbalance=rs=.04:bs=-.04:rm=.02:bm=-.03,unsharp=5:5:0.5,vignette=PI/5"
ENC=(-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -an)

# seg <name> <clip> <start> <src-duration> <speed> <overlay> <ov-in> <ov-out|->
seg() {
  local name=$1 clip=$2 ss=$3 t=$4 speed=$5 ov=$6 oin=$7 oout=$8
  local dur; dur=$(awk "BEGIN{print $t/$speed}")
  local ofade="fade=in:st=$oin:d=0.3:alpha=1"
  [[ "$oout" != "-" ]] && ofade="$ofade,fade=out:st=$oout:d=0.3:alpha=1"
  ffmpeg -v error -y -ss "$ss" -t "$t" -i "$SRC/$clip" -loop 1 -t "$dur" -i "$OV/ov_$ov.png" \
    -filter_complex "[0:v]setpts=(PTS-STARTPTS)/$speed,fps=30,scale=1080:1920,setsar=1,$GRADE[v];[1:v]format=rgba,$ofade[o];[v][o]overlay=0:0:shortest=1" \
    -t "$dur" "${ENC[@]}" "$WORK/$name.mp4"
  echo "built $name (${dur}s)"
}

seg s1 IMG_0558.MOV 0.0  3.0  1   hook   0.1  2.6
seg s2 IMG_0550.MOV 2.0  6.0  1.5 pro    0.2  3.5
seg s3 IMG_0549.MOV 1.0  6.0  1.5 streg  0.2  3.5
seg s4 IMG_0553.MOV 2.0  29.0 3   reveal 0.2  3.4
seg s5 IMG_0550.MOV 17.6 2.5  1   name   0.3  -

# End card: blurred last frame of the closing shot + brand card
ffmpeg -v error -y -ss 20.0 -i "$SRC/IMG_0550.MOV" -frames:v 1 -vf "scale=1080:1920,$GRADE" "$WORK/endbg.png"
ffmpeg -v error -y -loop 1 -t 3.5 -i "$WORK/endbg.png" -loop 1 -t 3.5 -i "$OV/ov_end.png" \
  -filter_complex "[0:v]boxblur=24:2,fps=30,setsar=1[b];[1:v]format=rgba,fade=in:st=0:d=0.4:alpha=1[o];[b][o]overlay=0:0" \
  -t 3.5 "${ENC[@]}" "$WORK/s6.mp4"
echo "built s6 (3.5s)"

printf "file '%s'\n" s1.mp4 s2.mp4 s3.mp4 s4.mp4 s5.mp4 s6.mp4 > "$WORK/list.txt"
ffmpeg -v error -y -f concat -safe 0 -i "$WORK/list.txt" -c copy -movflags +faststart "$OUTDIR/ditvindue-reel.mp4"

# Web version: smaller, for the homepage
ffmpeg -v error -y -i "$OUTDIR/ditvindue-reel.mp4" -vf "scale=540:960" \
  -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-reel-web.mp4"

# Poster: clear window at the end of the reveal
ffmpeg -v error -y -ss 30.5 -i "$SRC/IMG_0553.MOV" -frames:v 1 -vf "scale=540:960,$GRADE" -q:v 3 "$OUTDIR/ditvindue-reel-poster.jpg"

ls -la "$OUTDIR"
