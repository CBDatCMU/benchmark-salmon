#!/usr/bin/env python3
"""
Core Salmon quantification benchmark driver.

Sweeps across the 9 synthetic datasets (1M/10M/50M reads x 76/100/150bp) and
6 thread counts (1,2,4,8,16,32), running `salmon quant` for each combination
and recording wall time, CPU utilization, and peak memory.

Metrics are collected via os.wait4() on the salmon subprocess directly (no
`/usr/bin/time` dependency -- that binary isn't present on every node, e.g.
lanec2). os.wait4() returns the exact resource usage (ru_utime, ru_stime,
ru_maxrss) for that one child process, which is more precise than GNU time's
own accounting and works identically on any Linux node.

Usage:
    python3 run_salmon_benchmark.py \
        --index /path/to/salmon_index \
        --reads-dir /path/to/flux_simulator_reads \
        --node lanec2 \
        --out results/lanec2/salmon_benchmark.csv \
        [--index-build-time /path/to/index_build_time.txt]

Assumes each dataset lives under <reads-dir>/<reads>reads_<len>bp/ and contains
paired-end gzipped FASTQ files named simulation_1.fastq.gz / simulation_2.fastq.gz,
as produced by read_simulation/generate_reads.sh (dwgsim). Salmon reads gzipped
FASTQ natively, so these are left compressed.
"""

import argparse
import csv
import os
import subprocess
import sys
import time
from pathlib import Path

READ_COUNTS = [1_000_000, 10_000_000, 50_000_000]
READ_LENGTHS = [76, 100, 150]
THREAD_COUNTS = [1, 2, 4, 8, 16, 32]

READ1_NAME = "simulation_1.fastq.gz"
READ2_NAME = "simulation_2.fastq.gz"


def run_one(index_dir: Path, reads_dir: Path, reads: int, length: int, threads: int, tmp_out: Path):
    dataset_dir = reads_dir / f"{reads}reads_{length}bp"
    r1 = dataset_dir / READ1_NAME
    r2 = dataset_dir / READ2_NAME

    if not r1.exists() or not r2.exists():
        print(f"  [skip] missing reads for {dataset_dir}", file=sys.stderr)
        return None

    quant_out = tmp_out / f"{reads}reads_{length}bp_t{threads}"
    quant_out.mkdir(parents=True, exist_ok=True)
    log_path = quant_out / "salmon_stdout_stderr.log"

    cmd = [
        "salmon", "quant",
        "-i", str(index_dir),
        "-l", "A",
        "-1", str(r1), "-2", str(r2),
        "-p", str(threads),
        "-o", str(quant_out),
    ]

    wall_start = time.time()
    with open(log_path, "w") as log_file:
        proc = subprocess.Popen(cmd, stdout=log_file, stderr=subprocess.STDOUT)
        _, status, usage = os.wait4(proc.pid, 0)
    wall_time_sec = time.time() - wall_start

    returncode = os.WEXITSTATUS(status) if os.WIFEXITED(status) else -1
    cpu_time = usage.ru_utime + usage.ru_stime
    cpu_percent = round(100 * cpu_time / wall_time_sec) if wall_time_sec > 0 else None
    peak_mem_mb = usage.ru_maxrss / 1024  # ru_maxrss is in KB on Linux

    return {
        "reads": reads,
        "read_length": length,
        "threads": threads,
        "wall_time_sec": round(wall_time_sec, 3),
        "cpu_percent": cpu_percent,
        "peak_mem_mb": round(peak_mem_mb, 1),
        "returncode": returncode,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--index", required=True, type=Path)
    ap.add_argument("--reads-dir", required=True, type=Path)
    ap.add_argument("--node", required=True, help="e.g. lanec2 or bridges2_rm")
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--index-build-time", type=Path, default=None)
    ap.add_argument("--tmp-out", type=Path, default=Path("/tmp/salmon_quant_out"))
    args = ap.parse_args()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.tmp_out.mkdir(parents=True, exist_ok=True)

    index_build_time = None
    if args.index_build_time and args.index_build_time.exists():
        index_build_time = args.index_build_time.read_text().strip()

    fieldnames = [
        "node", "reads", "read_length", "threads",
        "wall_time_sec", "cpu_percent", "peak_mem_mb",
        "index_build_time_sec", "returncode",
    ]

    with open(args.out, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for reads in READ_COUNTS:
            for length in READ_LENGTHS:
                for threads in THREAD_COUNTS:
                    print(f"[{args.node}] reads={reads} length={length} threads={threads}")
                    result = run_one(args.index, args.reads_dir, reads, length, threads, args.tmp_out)
                    if result is None:
                        continue
                    result["node"] = args.node
                    result["index_build_time_sec"] = index_build_time
                    writer.writerow(result)
                    f.flush()

    print(f"Done. Results written to {args.out}")


if __name__ == "__main__":
    main()
