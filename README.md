# bench.sh

Tiny normalized CLI benchmark for Linux written in **Bash** (system tools only).  
It measures **CPU (single & multicore)**, **RAM**, **DISK**, and optionally **GPU** (with `glxgears`).  
Scores are **normalized** (≈1000 on a reference machine). **Higher is better**.  
Multiple runs are taken and the **median** is used to reduce variance.

## Features

- Pure Bash + common tools (`bash`, `bc`, `dd`, `time`, `awk`, `sed`).
- Tests:
  - **CPU single-core**: π via `bc` (5000 digits).
  - **CPU multicore**: π via `bc` in parallel (`nproc` workers).
  - **RAM**: `/dev/zero` → `/dev/null` (size configurable).
  - **DISK**: sequential write (tries `oflag=direct` + `fdatasync`).
  - **GPU (opt.)**: `glxgears` without vsync (if present).
- Colored output with per-test scores and a final **weighted total**:
  - CPU 1-core: 30%  
  - CPU multicore: 30%  
  - RAM: 20%  
  - DISK: 10%  
  - GPU: 10%  
  (If a test is skipped, its weight is ignored.)

## Quick run (no git)

**cURL**

```bash
curl -fsSL https://raw.githubusercontent.com/vroby65/bench.sh/main/bench.sh -o bench.sh \
&& chmod +x bench.sh \
&& ./bench.sh
```

**wget**

```bash
wget -q https://raw.githubusercontent.com/vroby65/bench.sh/main/bench.sh -O bench.sh \
&& chmod +x bench.sh \
&& ./bench.sh
```

## Usage

```bash
./bench.sh                         # defaults
RUNS=5 SIZE_MB=1024 ./bench.sh     # more stable runs
```

### Normalization (tune baselines)

To set scores ≈1000 on your current machine:

```bash
CPU_BASE_S=12.48 CPU_MULTI_BASE_S=8.00 \
RAM_BASE_S_512=0.0385 DISK_BASE_S_512=0.264 \
GPU_BASE_FPS=4922 ./bench.sh
```

## Environment variables

- `RUNS` (default `3`) – repetitions; median is used.

- `SIZE_MB` (default `512`) – payload for RAM/DISK tests.

Baselines (for ~1000 points):

- `CPU_BASE_S` (default `12.5`) – time for π (single core, s).

- `CPU_MULTI_BASE_S` (default `8.0`) – time for π with `nproc=1`.

- `RAM_BASE_S_512` (default `0.035`) – 512 MB RAM time (s).

- `DISK_BASE_S_512` (default `0.70`) – 512 MB DISK time (s).

- `GPU_BASE_FPS` (default `3000`) – reference FPS.

> If `glxgears` is not installed, GPU is skipped and the total is re-weighted.

## Tips for repeatability

- Close background apps; increase `RUNS` and `SIZE_MB`.

- Disk “cold” runs (root):
  
  ```bash
  sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
  ```

- CPU governor (root):
  
  ```bash
  sudo cpupower frequency-set -g performance
  ```

- GPU: keep `glxgears` window visible; vsync is disabled in the script.

## License

MIT

