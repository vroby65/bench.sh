#!/usr/bin/env bash
# bench.sh - tiny normalized CLI benchmark (higher is better, ~1000 baseline)

export LC_ALL=C LANG=C
SIZE_MB=${SIZE_MB:-512}
RUNS=${RUNS:-3}
CPU_BASE_S=${CPU_BASE_S:-12.5}
RAM_BASE_S_512=${RAM_BASE_S_512:-0.035}
DISK_BASE_S_512=${DISK_BASE_S_512:-0.70}
GPU_BASE_FPS=${GPU_BASE_FPS:-3000}

# -- colors (ANSI) --
RST='\033[0m'; BLD='\033[1m'; DIM='\033[2m'
RED='\033[31m'; GRN='\033[32m'; YLW='\033[33m'
BLU='\033[34m'; MAG='\033[35m'; CYN='\033[36m'; WHT='\033[37m'
say(){ printf "%b%s%b\n" "$1" "$2" "$RST" >&2; }

# -- tiny helpers --
calc(){ bc -l <<<"$1"; }
dur(){ local s e; s=$(date +%s.%N); "$@" >/dev/null 2>&1; e=$(date +%s.%N); calc "$e-$s"; }
med(){ sort -g | awk '{a[NR]=$1} END{m=int((NR+1)/2); print a[m]}'; }
int(){ cut -d. -f1; }

# -- banner --
say "$BLD$CYN" "┌─ bench.sh • tiny normalized benchmark • higher is better ─┐"

cpu(){ say "$BLD$MAG" "⚙️  CPU (pi 5000d)"
  vals=$(seq "$RUNS" | while read _; do dur bash -c 'echo "scale=5000;4*a(1)"|bc -l -q'; done)
  t=$(printf "%s\n" "$vals" | med)
  p=$(calc "1000*$CPU_BASE_S/($t+0.000001)" | int)
  say "$MAG" "CPU: ${t}s → ${p} pts"; echo "$p"; }

ram(){ say "$BLD$GRN" "🧮 RAM (zero→null ${SIZE_MB}M)"
  vals=$(seq "$RUNS" | while read _; do dur dd if=/dev/zero of=/dev/null bs=1M count="$SIZE_MB" status=none; done)
  t=$(printf "%s\n" "$vals" | med)
  base=$(calc "$RAM_BASE_S_512*($SIZE_MB/512)")
  p=$(calc "1000*$base/($t+0.000001)" | int)
  say "$GRN" "RAM: ${t}s → ${p} pts"; echo "$p"; }

disk(){ say "$BLD$YLW" "💾 DISK (write ${SIZE_MB}M)"
  vals=$(seq "$RUNS" | while read _; do
    dur bash -c "dd if=/dev/zero of=./benchfile bs=1M count=$SIZE_MB oflag=direct status=none 2>/dev/null || dd if=/dev/zero of=./benchfile bs=1M count=$SIZE_MB status=none 2>/dev/null; sync; rm -f ./benchfile"
  done)
  t=$(printf "%s\n" "$vals" | med)
  base=$(calc "$DISK_BASE_S_512*($SIZE_MB/512)")
  p=$(calc "1000*$base/($t+0.000001)" | int)
  say "$YLW" "DISK: ${t}s → ${p} pts"; echo "$p"; }

gpu(){ say "$BLD$BLU" "🎮 GPU (glxgears ~7s, no-vsync)"
  command -v glxgears >/dev/null || { say "$DIM$BLU" "GPU: glxgears not found (skipped)"; return; }
  vals=$(seq "$RUNS" | while read _; do
    timeout 7s env __GL_SYNC_TO_VBLANK=0 vblank_mode=0 glxgears 2>&1 |
    awk '/frames in/ {print $(NF-1)}' | sed 's/,/./'
  done)
  fps=$(printf "%s\n" "$vals" | med)
  [ -z "$fps" ] && { say "$DIM$BLU" "GPU: no FPS read (skipped)"; return; }
  p=$(calc "1000*($fps)/$GPU_BASE_FPS" | int)
  say "$BLU" "GPU: ${fps} FPS → ${p} pts"; echo "$p"; }

# -- run & average only available tests --
sum=0; n=0
for v in "$(cpu)" "$(ram)" "$(disk)" "$(gpu)"; do [ -n "$v" ] && sum=$((sum+v)) && n=$((n+1)); done
avg=$(calc "$sum/$n" | int)

say "$BLD$CYN" "└────────────────────────────────────────────────────────────┘"
say "$BLD$WHT" "Total (avg of ${n} tests): ${avg} pts"

