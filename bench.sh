#!/usr/bin/env bash
# bench.sh - tiny normalized CLI benchmark (higher is better, ~1000 baseline)

export LC_ALL=C LANG=C
SIZE_MB=${SIZE_MB:-512}
RUNS=${RUNS:-3}
CPU_BASE_S=${CPU_BASE_S:-12.5}
CPU_MULTI_BASE_S=${CPU_MULTI_BASE_S:-8.0}
RAM_BASE_S_512=${RAM_BASE_S_512:-0.035}
DISK_BASE_S_512=${DISK_BASE_S_512:-0.70}
GPU_BASE_FPS=${GPU_BASE_FPS:-3000}

# weights (should sum ~100)
W_CPU1=30
W_CPUM=30
W_RAM=20
W_DISK=10
W_GPU=10

# -- colors --
RST='\033[0m'; BLD='\033[1m'; DIM='\033[2m'
RED='\033[31m'; GRN='\033[32m'; YLW='\033[33m'
BLU='\033[34m'; MAG='\033[35m'; CYN='\033[36m'; WHT='\033[37m'
say(){ printf "%b%s%b\n" "$1" "$2" "$RST" >&2; }

# -- helpers --
calc(){ bc -l <<<"$1"; }

dur(){
  local t
  TIMEFORMAT=%R
  { time "$@" >/dev/null 2>&1; } 2> >(read t; echo "$t")
}
med(){ sort -g | awk '{a[NR]=$1} END{m=int((NR+1)/2); print a[m]}'; }
int(){ cut -d. -f1; }

# -- banner --
say "$BLD$CYN" "┌─ bench.sh • tiny normalized benchmark • higher is better ─┐"

cpu_single(){
  vals=$(seq "$RUNS" | while read _; do dur bash -c 'echo "scale=5000;4*a(1)" | bc -l -q'; done)
  t=$(printf "%s\n" "$vals" | med)
  [ -z "$t" ] && return
  p=$(calc "1000*$CPU_BASE_S/($t+0.000001)" | int)
  say "$MAG" "CPU 1-core: ${t}s → ${p} pts"
  echo "$p"
}

cpu_multi(){
  cores=$(nproc 2>/dev/null || echo 1)
  vals=$(seq "$RUNS" | while read _; do
    dur bash -c "
      for i in \$(seq $cores); do
        echo 'scale=2000;4*a(1)' | bc -l -q >/dev/null &
      done
      wait
    "
  done)
  t=$(printf "%s\n" "$vals" | med)
  [ -z "$t" ] && return
  base=$(calc "$CPU_MULTI_BASE_S/$cores")
  p=$(calc "1000*$base/($t+0.000001)" | int)
  say "$CYN" "CPU ${cores}-core: ${t}s → ${p} pts"
  echo "$p"
}

ram(){
  vals=$(seq "$RUNS" | while read _; do dur dd if=/dev/zero of=/dev/null bs=64K count=$((SIZE_MB*1024/64)) status=none; done)
  t=$(printf "%s\n" "$vals" | med)
  [ -z "$t" ] && return
  base=$(calc "$RAM_BASE_S_512*($SIZE_MB/512)")
  p=$(calc "1000*$base/($t+0.000001)" | int)
  say "$GRN" "RAM: ${t}s → ${p} pts"
  echo "$p"
}

disk(){
  vals=$(seq "$RUNS" | while read _; do
    dur bash -c "
      dd if=/dev/zero of=./benchfile bs=1M count=$SIZE_MB oflag=direct conv=fdatasync status=none 2>/dev/null ||
      dd if=/dev/zero of=./benchfile bs=1M count=$SIZE_MB status=none 2>/dev/null
      sync; rm -f ./benchfile"
  done)
  t=$(printf "%s\n" "$vals" | med)
  [ -z "$t" ] && return
  base=$(calc "$DISK_BASE_S_512*($SIZE_MB/512)")
  p=$(calc "1000*$base/($t+0.000001)" | int)
  say "$YLW" "DISK: ${t}s → ${p} pts"
  echo "$p"
}

gpu(){
  command -v glxgears >/dev/null || { say "$DIM$BLU" "GPU: glxgears not found (skipped)"; return; }
  vals=$(seq "$RUNS" | while read _; do
    timeout 7s env __GL_SYNC_TO_VBLANK=0 vblank_mode=0 glxgears 2>&1 |
    awk '/frames in/ {print $(NF-1)}' | sed 's/,/./'
  done)
  fps=$(printf "%s\n" "$vals" | med)
  [ -z "$fps" ] && { say "$DIM$BLU" "GPU: no FPS read (skipped)"; return; }
  p=$(calc "1000*($fps)/$GPU_BASE_FPS" | int)
  say "$BLU" "GPU: ${fps} FPS → ${p} pts"
  echo "$p"
}

# -- run all tests --
score_cpu1=$(cpu_single)
score_cpum=$(cpu_multi)
score_ram=$(ram)
score_disk=$(disk)
score_gpu=$(gpu)

# -- weighted average --
sum=0; weight_sum=0
for test in cpu1 cpum ram disk gpu; do
  eval "v=\$score_${test}"
  eval "w=\$W_${test^^}"
  if [ -n "$v" ] && [ "$w" -gt 0 ]; then
    sum=$(calc "$sum + $v*$w")
    weight_sum=$((weight_sum+w))
  fi
done

if [ "$weight_sum" -eq 0 ]; then
  say "$RED$BLD" "Error: no valid tests executed"
  exit 1
fi

avg=$(calc "$sum/$weight_sum" | int)

# -- summary --
say "$BLD$CYN" "└────────────────────────────────────────────────────────────┘"
say "$BLD$WHT" "Scores:"
[ -n "$score_cpu1" ] && say "$WHT" "  CPU 1-core : $score_cpu1 pts"
[ -n "$score_cpum" ] && say "$WHT" "  CPU multi  : $score_cpum pts"
[ -n "$score_ram" ]  && say "$WHT" "  RAM        : $score_ram pts"
[ -n "$score_disk" ] && say "$WHT" "  DISK       : $score_disk pts"
[ -n "$score_gpu" ]  && say "$WHT" "  GPU        : $score_gpu pts"
say "$BLD$WHT" "Total (weighted avg, ${weight_sum}%): ${avg} pts"
