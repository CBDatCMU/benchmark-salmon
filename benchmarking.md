# Salmon Benchmarking

## Motivation

The original Salmon papers (Patro et al. 2017) benchmark quantification *accuracy* using Flux
Simulator-generated ground truth (76 bp reads). This project instead benchmarks *performance* --
wall time, CPU utilization, and peak memory -- to help PSC users pick the right node/thread count
for their RNA-seq workloads. Because our goal is performance rather than accuracy, we do not need
the papers' Flux Simulator ground truth; we generate synthetic reads with **dwgsim** instead
(flux-simulator is unmaintained since ~2012-2013 and it crashes on modern JDKs), using
longer reads (100-150 bp) to reflect modern RNA-seq experiments.

## Method

- **Data:** synthetic paired-end reads via dwgsim, simulated directly from the transcriptome, 9
  datasets (1M/10M/50M reads x 76/100/150 bp); mutations/indels disabled (`-r 0 -R 0`) since we
  time quantification rather than check accuracy
- **Index:** Salmon index built once per node from the reference transcriptome
- **Sweep:** `salmon quant --threads` in {1, 2, 4, 8, 16, 32} for each dataset
- **Nodes:** lanec2, Bridges-2 RM (CPU-only partition; Salmon does not use a GPU)
- **Metrics:** wall time, CPU utilization (%), peak memory (RSS), index build time vs. quant time
- **Tooling:** `/usr/bin/time -v` around each `salmon quant` invocation

## Results

The full 108-run matrix (9 datasets × 6 thread counts × 2 nodes) completed on both nodes, all with
returncode 0. Raw per-run CSVs are in `results/lanec2/` and `results/bridges2_rm/`
(`human_benchmark.csv` for the human GENCODE reference, `yeast_pilot.csv` for the validation run).

### 1. Thread scaling saturates at 8–16 threads, then regresses

Wall time drops sharply from 1 → 8 threads but flattens by 16 and often *increases* at 32. The
optimal thread count and the 1→8 speedup, per human dataset:

| Dataset | lanec2 optimal | lanec2 1→8 speedup | lanec2 32t vs 8t | Bridges-2 optimal | Bridges-2 1→8 speedup | Bridges-2 32t vs 8t |
|---|---|---|---|---|---|---|
| 1M, 76 bp | 8t | 2.8× | 1.34× slower | 8t | 2.0× | 1.28× slower |
| 1M, 100 bp | 8t | 2.9× | 1.50× slower | 8t | 2.4× | 1.72× slower |
| 1M, 150 bp | 8t | 3.5× | 1.20× slower | 8t | 2.4× | 1.64× slower |
| 10M, 76 bp | 32t | 3.8× | 0.85× (faster) | 8t | 3.2× | 1.39× slower |
| 10M, 100 bp | 16t | 3.8× | 0.96× | 16t | 3.0× | 1.35× slower |
| 10M, 150 bp | 16t | 4.2× | 0.96× | 16t | 3.8× | 1.19× slower |
| 50M, 76 bp | 16t | 5.2× | 0.95× | 16t | 4.2× | 1.06× slower |
| 50M, 100 bp | 32t | 5.3× | 0.80× (faster) | 16t | 4.6× | 0.96× |
| 50M, 150 bp | 16t | 6.3× | 0.78× (faster) | 16t | 5.4× | 1.10× slower |

Small inputs (1M) peak at 8 threads; larger inputs (10M–50M) peak at 16. On no dataset does 32
threads give a meaningful win over 16, and on Bridges-2 it is reliably slower.

### 2. The ceiling is a serial bottleneck

At 32 threads, measured CPU utilization only reaches ~950–1750% on lanec2 and ~1580–1800% on
Bridges-2 which means roughly 10–18 of the 32 requested cores are actually busy. Parts of the Salmon
pipeline (for example: index loading and equivalence-class accounting) are effectively serial, so adding threads
past the saturation point contributes coordination overhead without doing more parallel work.

### 3. Memory is set by the workload

Human peak memory ranges 2.6–6.6 GB and tracks read count (≈2.6 GB at 1M → 5–6.6 GB at 50M),
dominated by the large human equivalence-class table. Thread count has only a secondary effect
(per-thread buffers add up to ~1 GB, most visible at small read counts). ~8 GB RAM is a safe
request for human-scale workloads on either node; memory is not the limiting resource.

### 4. Read length is a minor factor

150 bp runs are ~20–30% slower than 76 bp at a fixed read count and thread count with comparable
memory. Read count and thread count dominate; read length is secondary.

### 5. lanec2 vs Bridges-2 RM

Matched-configuration wall-time ratio (Bridges-2 ÷ lanec2; >1 means lanec2 is faster):

| Threads | Median ratio | Interpretation |
|---|---|---|
| 1 | 0.98 | tied |
| 8 | 1.15 | lanec2 ≈15% faster |
| 16 | 1.29 | lanec2 ≈29% faster |
| 32 | 1.46 | lanec2 ≈46% faster |

The two nodes are tied single-threaded; lanec2 scales better as threads increase, because it
reaches the serial ceiling more gracefully.

### 6. Yeast pilot — the opposite memory regime

With *S. cerevisiae*'s tiny equivalence-class table, peak memory is dominated by per-thread buffers
and climbs steeply with threads (≈107 MB at 1 thread → ≈1.1 GB at 32 on lanec2, 1M/76 bp), rather
than by the reference. Runtimes are sub-minute, so thread overhead dominates and 8 threads already
saturates the useful parallelism. This confirms the pipeline end-to-end and illustrates how the
memory profile flips between a tiny and a human-scale reference.

## Discussion

**Recommendation for PSC users.** For human-scale Salmon quantification, request **8–16 threads**
and **~8 GB RAM**. Requesting 32 threads wastes an allocation and can make jobs slower, because the
pipeline does not parallelize past ~16 effective cores.

**Which node.** For a *single* job, lanec2 is as fast or faster than a Bridges-2 RM node, so raw
per-job speed is not a reason to migrate. Bridges-2 RM is the right choice when the user needs
**throughput** (many quant jobs in parallel across nodes) or wants to avoid contending for the
shared lab workstation with accepting queue wait and the need for an RM allocation in exchange.

**Caveats and follow-ups.**

- A portion of Salmon's index/memory-search step is single-threaded regardless of `--threads`; a
  dedicated sensitivity analysis would quantify how much of the wall time is this serial floor.
- Both nodes were swept only up to 32 threads. A run on Bridges-2's larger-core nodes, compared
  against 32 threads, would confirm whether the regression past 16 threads continues or worsens.
- Numbers are single runs per configuration; repeating a few points would give a sense of
  run-to-run variance, especially on the shared RM partition.
