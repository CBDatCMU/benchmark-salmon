# Salmon Benchmarking

## Motivation

The original Salmon papers (Patro et al. 2017) benchmark quantification *accuracy* using Flux
Simulator-generated ground truth (76 bp reads). This project instead benchmarks *performance* --
wall time, CPU utilization, and peak memory -- to help PSC users pick the right node/thread count
for their RNA-seq workloads. We reuse only the Flux Simulator data-generation method from the
original papers, with longer reads (100-150 bp) to reflect modern RNA-seq experiments.

## Method

- **Data:** synthetic paired-end reads via Flux Simulator, 9 datasets (1M/10M/50M reads x
  76/100/150 bp)
- **Index:** Salmon index built once per node from the reference transcriptome
- **Sweep:** `salmon quant --threads` in {1, 2, 4, 8, 16, 32} for each dataset
- **Nodes:** lanec2, Bridges-2 RM (CPU-only partition; Salmon does not use a GPU)
- **Metrics:** wall time, CPU utilization (%), peak memory (RSS), index build time vs. quant time
- **Tooling:** `/usr/bin/time -v` around each `salmon quant` invocation

## Results

_(to be filled in after runs complete)_

## Discussion

_(to be filled in)_
