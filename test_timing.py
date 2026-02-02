#!/usr/bin/env python3
import time
import subprocess
import sys

binary = "./test_rej_uniform_sve" if len(sys.argv) < 2 else sys.argv[1]

print(f"Running: {binary}")
start = time.perf_counter_ns()
result = subprocess.run(binary, shell=True)
end = time.perf_counter_ns()

elapsed_ns = end - start
elapsed_us = elapsed_ns / 1000.0
elapsed_s = elapsed_ns / 1_000_000_000.0

print(f"\nTotal time: {elapsed_s:.3f} seconds = {elapsed_us:.3f} us = {elapsed_ns:.0f} ns")
