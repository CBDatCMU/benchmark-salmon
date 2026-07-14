# benchmark-salmon

Performance benchmarking of [Salmon](https://github.com/COMBINE-lab/salmon) RNA-seq transcript
quantification across HPC nodes at PSC / CMU CompBio.

**Goal:** unlike the original Salmon papers (Patro et al. 2017), which benchmark *accuracy* against
ground-truth expression profiles, this project benchmarks **performance** — wall time, CPU
utilization, and peak memory — to help PSC users choose the right node for their RNA-seq workloads.

## Benchmark dimensions

| Dimension | Values |
|---|---|
| Input reads | 1M, 10M, 50M |
| Read length | 76 bp, 100 bp, 150 bp |
| Threads (`salmon --threads`) | 1, 2, 4, 8, 16, 32 |
| Nodes | lanec2, Bridges-2 RM (CPU partition) |
| Metrics | wall time, CPU utilization, peak memory (RSS), index time vs. quant time |
| Data | synthetic reads generated with Flux Simulator (data-generation method only, borrowed from Patro et al. 2017 — our goal is performance, not accuracy) |

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
2. `bash flux_simulator/generate_reads.sh` — simulate the 9 read datasets (1M/10M/50M x 76/100/150bp)
3. `bash build_index.sh <reference.fa> <index_dir>` — build the Salmon index once per node
4. Run the sweep:
   - lanec2: `nohup bash submit_lanec2.sh > lanec2_run.log 2>&1 &`
   - Bridges-2 RM: `sbatch submit_bridges2_rm.sh`
5. Results land as CSV files under `results/<node>/`

## Status

Planning stage — awaiting RM partition allocation on Bridges-2 (currently only GPU hours available
under `cis260196p`), and input from Guillaume Marçais / Rob Patro on benchmark scope.
