#!/usr/bin/env python3
"""
Core Salmon quantification benchmark driver.

Sweeps across the 9 synthetic datasets (1M/10M/50M reads x 76/100/150bp) and
6 thread counts (1,2,4,8,16,32), running `salmon quant` for each combination
and recording wall time, CPU utilization, and peak memory via `/usr/bin/time -v`.

Usage:
    python3 run_salmon_benchmark.py \
        --index /path/to/salmon_index \
        --reads-dir /path/to/flux_simulator_reads \
        --node lanec2 \
        --out results/lanec2/salmon_benchmark.csv \
        [--index-build-time /path/to/index_build_time.txt]

Assumes each dataset lives under <reads-dir>/<reads>reads_<len>bp/ and contains
paired-end FASTA files named simulation_1.fastq / simulation_2.fastq, as
produced by flux_simulator/generate_reads.sh (which splits Flux Simulator's
single interleaved output into separate mate1/mate2 files).
"""

import argparse
import csv
import re
import subprocess
import sys
import time
from pathlib import Path

READ_COUNTS = [1_000_000, 10_000_000, 50_000_000]
READ_LENGTHS = [76, 100, 150]
THREAD_COUNTS = [1, 2, 4, 8, 16, 32]

READ1_NAME = "simulation_1.fastq.gz"
READ2_NAME = "simulation_2.fastq.gz"


def parse_time_v(stderr_text: str) -> dict:
    """Parse `/usr/bin/time -v` output for wall time, max RSS, and CPU%."""
    wall_time_match = re.search(r"Elapsed \(wall clock\) time.*?: (.+)", stderr_text)
    max_rss_match = re.search(r"Maximum resident set size \(kbytes\): (\d+)", stderr_text)
    cpu_pct_match = re.search(r"Percent of CPU this job got: (\d+)%", stderr_text)

    wall_time_raw = wall_time_match.group(1).strip() if wall_time_match else None
    wall_time_sec = _wall_time_to_seconds(wall_time_raw) if wall_time_raw else None

    return {
        "wall_time_sec": wall_time_sec,
        "peak_mem_mb": (int(max_rss_match.group(1)) / 1024) if max_rss_match else None,
        "cpu_percent": int(cpu_pct_match.group(1)) if cpu_pct_match else None,
    }


def _wall_time_to_seconds(raw: str) -> float:
    # Formats: "h:mm:ss" or "m:ss.ss"
    parts = raw.split(":")
    parts = [float(p) for p in parts]
    if len(parts) == 3:
        h, m, s = parts
        return h * 3600 + m * 60 + s
    elif len(parts) == 2:
        m, s = parts
        return m * 60 + s
    return float(raw)


def run_one(index_dir: Path, reads_dir: Path, reads: int, length: int, threads: int, tmp_out: Path):
    dataset_dir = reads_dir / f"{reads}reads_{length}bp"
    r1 = dataset_dir / READ1_NAME
    r2 = dataset_dir / READ2_NAME

    if not r1.exists() or not r2.exists():
        print(f"  [skip] missing reads for {dataset_dir}", file=sys.stderr)
        return None

    quant_out = tmp_out / f"{reads}reads_{length}bp_t{threads}"
    cmd = [
        "/usr/bin/time", "-v",
        "salmon", "quant",
        "-i", str(index_dir),
        "-l", "A",
        "-1", str(r1), "-2", str(r2),
        "-p", str(threads),
        "-o", str(quant_out),
    ]

    proc = subprocess.run(cmd, capture_output=True, text=True)
    metrics = parse_time_v(proc.stderr)
    metrics.update({
        "reads": reads,
        "read_length": length,
        "threads": threads,
        "returncode": proc.returncode,
    })
    return metrics


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
