# benchmark-salmon

Performance benchmarking of [Salmon](https://github.com/COMBINE-lab/salmon) RNA-seq transcript
quantification across HPC nodes at PSC / CMU CompBio.

**Goal:** The original Salmon papers (Patro et al. 2017) benchmark quantification **accuracy**. This project
instead benchmarks **performance** — wall time, CPU utilization, and peak memory — so PSC users can
choose the right node and thread count for their RNA-seq workloads. Reads are generated with
**dwgsim** 
We sweep the human GENCODE transcriptome across **1M–50M reads × 76–150 bp × 1–32 threads**, on **lanec2** (lab
workstation) and **Bridges-2 RM** (CPU partition). Salmon is CPU-only, so no GPU is involved.

## Benchmark dimensions

| Dimension | Values |
|---|---|
| Input reads | 1M, 10M, 50M |
| Read length | 76 bp, 100 bp, 150 bp |
| Threads (`salmon --threads`) | 1, 2, 4, 8, 16, 32 |
| Nodes | lanec2, Bridges-2 RM (CPU partition) |
| Metrics | wall time, CPU utilization, peak memory (RSS), index time vs. quant time |
| Data | synthetic reads generated with **dwgsim** |

## Results Summary

Full 108-run matrix (9 datasets × 6 thread counts × 2 nodes) completed; all runs returned cleanly.
Raw CSVs are in [`results/`](results/); full analysis in [`benchmarking.md`](benchmarking.md).

**Headline numbers (human reference):**

- **Optimal thread count: 8–16** 
- **1 → 8 threads: up to ~6× faster.** **8 → 32 threads: no gain, often slower.**
- **Peak memory 2.6–6.6 GB**
- **lanec2 vs Bridges-2 RM:** tied at 1 thread; lanec2 is ~15% / 29% / 46% faster at 8 / 16 / 32 threads.

**Representative workload — human, 50M reads, 150 bp** (**bold** = fastest):

| Threads | lanec2 wall (s) | Bridges-2 RM wall (s) | Peak mem (GB) |
|---|---|---|---|
| 1 | 3105 | 3058 | ~4.8 |
| 2 | 1555 | 1689 | ~4.7 |
| 4 | 830 | 949 | ~4.8 |
| 8 | 492 | 567 | ~4.9 |
| **16** | **385** | **483** | ~4.9 |
| 32 | 386 | 625 | ~5.2 |

## Guide for Users

- **Threads:** request **8–16**. Requesting more than 16 wastes your allocation and can make the job slower.
- **Memory:** budget **~8 GB** for a human-scale index: memory is not the bottleneck on either node.
- **Which node:**
  - **lanec2** — a single job runs as fast or faster here, with no queue. Best for one-off runs.
  - **Bridges-2 RM** — choose it to run **many jobs in parallel** or to free up the shared lab
    machine. Trade-off: queue wait, and you need an RM allocation. Not faster for a single job.

## Repository layout

```
benchmark-salmon/
├── reference/                  # reference genome + annotation used to simulate reads
│   └── download_reference.sh
├── flux_simulator/              # synthetic RNA-seq read generation
│   ├── generate_reads.sh        # generates all 9 (read count x length) datasets
│   └── configs/                 # generated .par files (not committed, see .gitignore)
├── build_index.sh               # builds the Salmon index (once per node)
├── run_salmon_benchmark.py      # core benchmark driver: sweeps datasets x threads, records metrics
├── submit_lanec2.sh             # nohup wrapper for lanec2 (no job scheduler)
├── submit_bridges2_rm.sh        # SLURM sbatch wrapper for Bridges-2 RM partition
├── results/
│   ├── lanec2/                  # CSV results from lanec2 runs
│   └── bridges2_rm/             # CSV results from Bridges-2 RM runs
└── benchmarking.md              # write-up: methodology, findings, plots
```

## Usage

0. **Pipeline validation (recommended first pass):** use `reference/download_reference_yeast.sh`
   instead of `download_reference.sh` — a small *S. cerevisiae* reference (~12Mb, ~6000
   transcripts) to confirm the whole pipeline works end-to-end quickly, before committing to the
   full human GENCODE reference and the full 108-run matrix.
1. `bash reference/download_reference.sh` — fetch reference genome + GTF
2. Create a dedicated Flux Simulator env (newer JDKs break it via
   `InaccessibleObjectException`) and activate it:
   `mamba create -n flux-sim -c bioconda -c conda-forge flux-simulator openjdk=8 -y && conda activate flux-sim`
3. `bash flux_simulator/generate_reads.sh reference/genome.fa reference/annotation.gtf <output_dir>`
   — simulates the 9 read datasets (1M/10M/50M x 76/100/150bp). Auto-splits the genome into
   per-chromosome FASTA files (Flux Simulator requirement) and per-dataset mate1/mate2 FASTA
   files (for `salmon quant -1/-2`) on first run.
4. `bash build_index.sh <reference.fa> <index_dir>` — build the Salmon index once per node
5. Run the sweep:
   - lanec2: `nohup bash submit_lanec2.sh > lanec2_run.log 2>&1 &`
   - Bridges-2 RM: `sbatch submit_bridges2_rm.sh`
6. Results land as CSV files under `results/<node>/`

## Status

Planning stage — awaiting RM partition allocation on Bridges-2 (currently only GPU hours available
under `cis260196p`), and input from Guillaume Marçais / Rob Patro on benchmark scope.
