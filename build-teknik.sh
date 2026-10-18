#!/usr/bin/env bash
# Builds "Teknikken" (9:16) and the soap/squeegee split-screen (4:5) in the site's paper/ink/green look.
# Usage: bash build-teknik.sh <source-dir> <cards-dir> <work-dir>
set -euo pipefail

SRC="$1"; CARDS="$2"; WORK="$3"
OUTDIR="billeder/video"
mkdir -p "$WORK" "$OUTDIR"

GRADE="eq=contrast=1.08:saturation=1.15:gamma=1.02,colorbalance=rs=.03:bs=-.03:rm=.02:bm=-.02,unsharp=5:5:0.6"
ENC=(-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -an)
PAPER="0xECEAE3"
dur_of() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }

# zoom(Zexpr, fx, fy): scale the 1000x1778 frame by Z(t) and crop the 1000x1640 hole around focus (fx, fy in 0..1)
zoom() { echo "scale=1000:1778,scale=w='trunc(1000*($1)/2)*2':h='trunc(1778*($1)/2)*2':eval=frame,crop=1000:1640:x='(iw-1000)*$2':y='(ih-1640)*$3'"; }
frame() { echo "pad=1080:1920:40:140:color=$PAPER,setsar=1"; }

# seg <name> <clip> <ss> <t> <speed> <chapter> <Z> <fx> <fy> [extra-pre-filter]
seg() {
  local name=$1 clip=$2 ss=$3 t=$4 speed=$5 ch=$6 z=$7 fx=$8 fy=$9 pre=${10:-}
  local d; d=$(awk "BEGIN{print $t/$speed}")
  ffmpeg -v error -y -ss "$ss" -t "$t" -i "$SRC/$clip" -i "$CARDS/card_chrome_$ch.png" \
    -filter_complex "[0:v]setpts=(PTS-STARTPTS)/$speed,${pre}fps=30,$(zoom "$z" "$fx" "$fy"),$GRADE,$(frame)[v];[v][1:v]overlay=0:0" \
    -t "$d" "${ENC[@]}" "$WORK/$name.mp4"
  echo "built $name (${d}s)"
}

# ----- Teknikken -----
# title: paper card, headline rises in
ffmpeg -v error -y -loop 1 -t 1.8 -i "$CARDS/card_title.png" -loop 1 -t 1.8 -i "$CARDS/card_titletext.png" \
  -filter_complex "[0:v]fps=30,format=yuv420p[b];[1:v]format=rgba,fade=in:st=0:d=0.35:alpha=1[t];[b][t]overlay=x=0:y='300*pow(1-min(t/0.6\,1)\,3)'" \
  -t 1.8 "${ENC[@]}" "$WORK/t0.mp4"

seg t1 IMG_0546.MOV 3.3 2.8 1 01 "1+0.22*min(t/2.8\,1)" 0.5 0.4
seg t2 IMG_0548.MOV 8.6 3.0 1 02 "if(lt(t\,0.35)\,1+0.3*sin(PI/2*t/0.35)\,1.3-0.3*(t-0.35)/2.65)" 0.55 0.35
seg t3 IMG_0548.MOV 13.2 1.5 0.5 03 "1+0.45*pow(min(t/3\,1)\,1.4)" 0.55 0.85 \
  "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=2*PTS,"

# freeze on the last slow-mo frame, zoom back out, callouts appear
ffmpeg -v error -y -ss 14.7 -i "$SRC/IMG_0548.MOV" -frames:v 1 "$WORK/freeze.png"
ffmpeg -v error -y -loop 1 -t 2.2 -i "$WORK/freeze.png" -i "$CARDS/card_chrome_04.png" -loop 1 -t 2.2 -i "$CARDS/card_callout.png" \
  -filter_complex "[0:v]fps=30,$(zoom "if(lt(t\,0.6)\,1.45-0.45*sin(PI/2*t/0.6)\,1)" 0.55 0.85),$GRADE,$(frame)[v];[v][1:v]overlay=0:0[c];[2:v]format=rgba,fade=in:st=0.6:d=0.25:alpha=1[o];[c][o]overlay=0:0" \
  -t 2.2 "${ENC[@]}" "$WORK/t4.mp4"
echo "built t4 (2.2s)"

seg t5 IMG_0548.MOV 0.3 4.0 2 05 "1.25-0.25*min(t/0.5\,1)" 0.6 0.3
seg t6 IMG_0550.MOV 18.3 1.8 1 06 "1+0.35*min(t/1.4\,1)" 0.55 0.3

# end card with a gentle zoom-out settle
ffmpeg -v error -y -loop 1 -t 2.8 -i "$CARDS/card_end.png" \
  -filter_complex "[0:v]fps=30,scale=w='trunc(1080*(1+0.06*(1-min(t/0.8\,1)))/2)*2':h='trunc(1920*(1+0.06*(1-min(t/0.8\,1)))/2)*2':eval=frame,crop=1080:1920,format=yuv420p" \
  -t 2.8 "${ENC[@]}" "$WORK/t7.mp4"

# chain with transitions
names=(t0 t1 t2 t3 t4 t5 t6 t7)
trans=(slideup zoomin wipeleft fade slideleft zoomin slideup)
tdur=(0.4 0.3 0.25 0.1 0.3 0.3 0.4)
inputs=(); graph=""; prev="[0:v]"; off=0
for i in "${!names[@]}"; do inputs+=(-i "$WORK/${names[$i]}.mp4"); done
for i in "${!trans[@]}"; do
  d=$(dur_of "$WORK/${names[$i]}.mp4")
  [[ $i -eq 0 ]] && off=$(awk "BEGIN{print $d-${tdur[$i]}}") || off=$(awk "BEGIN{print $off+$d-${tdur[$i]}}")
  graph+="${prev}settb=AVTB[a$i];[$((i+1)):v]settb=AVTB[b$i];[a$i][b$i]xfade=transition=${trans[$i]}:duration=${tdur[$i]}:offset=$off[x$i];"
  prev="[x$i]"
done
# progress bar in the bottom band while chapters run: a 2000px strip (green | paper) cropped per frame
T0=$(awk "BEGIN{print $(dur_of "$WORK/t0.mp4")-0.4}")
TE=$(awk "BEGIN{print $off}")
TOTAL=$(awk "BEGIN{print $TE+$(dur_of "$WORK/t7.mp4")}")
N=${#names[@]}
inputs+=(-f lavfi -t "$TOTAL" -i "color=c=0x22D36B:s=1000x8:r=30" -f lavfi -t "$TOTAL" -i "color=c=$PAPER:s=1000x8:r=30")
graph+="[$N:v][$((N+1)):v]hstack=2,crop=1000:8:x='1000*(1-min(max((t-$T0)/($TE-$T0),0),1))':y=0[bar];${prev}[bar]overlay=x=40:y=1788:enable='between(t,$T0,$TE)'"
ffmpeg -v error -y "${inputs[@]}" -filter_complex "$graph" "${ENC[@]}" -movflags +faststart "$OUTDIR/ditvindue-teknik.mp4"
echo "built teknik ($(dur_of "$OUTDIR/ditvindue-teknik.mp4")s)"

# ----- Split-screen: soap | squeegee (1080x1350) -----
half() { echo "scale=760:1352,scale=w='trunc(760*($1)/2)*2':h='trunc(1352*($1)/2)*2':eval=frame,crop=532:1350:x='(iw-532)*0.5':y='(ih-1350)*0.45'"; }
ffmpeg -v error -y -ss 2.5 -t 7 -i "$SRC/IMG_0546.MOV" -ss 8.6 -t 7 -i "$SRC/IMG_0548.MOV" -loop 1 -t 7 -i "$CARDS/card_split.png" \
  -filter_complex "[0:v]fps=30,$(half "1+0.14*(1-cos(2*PI*t/3.5))/2"),$GRADE[l];[1:v]fps=30,$(half "1.14-0.14*(1-cos(2*PI*t/3.5))/2"),$GRADE[r];[l]pad=548:1350:0:0:color=0x121412[lp];[lp][r]hstack=2,setsar=1[s];[s][2:v]overlay=0:0" \
  -t 7 "${ENC[@]}" -movflags +faststart "$OUTDIR/ditvindue-skum-skraber.mp4"
echo "built skum-skraber (7s)"

# ----- web versions + posters -----
ffmpeg -v error -y -i "$OUTDIR/ditvindue-teknik.mp4" -vf "scale=540:960" -c:v libx264 -preset slow -crf 28 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-teknik-web.mp4"
ffmpeg -v error -y -i "$OUTDIR/ditvindue-skum-skraber.mp4" -vf "scale=720:900" -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -an -movflags +faststart "$OUTDIR/ditvindue-skum-skraber-web.mp4"
ffmpeg -v error -y -ss 1.0 -i "$OUTDIR/ditvindue-teknik.mp4" -frames:v 1 -vf "scale=540:960" -q:v 3 "$OUTDIR/ditvindue-teknik-poster.jpg"
ffmpeg -v error -y -ss 1.5 -i "$OUTDIR/ditvindue-skum-skraber.mp4" -frames:v 1 -vf "scale=720:900" -q:v 3 "$OUTDIR/ditvindue-skum-skraber-poster.jpg"
ls -la "$OUTDIR" | grep -E "teknik|skum"
