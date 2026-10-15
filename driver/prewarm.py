#!/home/atila/.local/share/rebench-venv/bin/python3
"""Run every executor/benchmark command of the experiment once, and discard
the output. This fills the on-disk caches (bin/sb dependency image, Python
.pyc files, JVM and OS file caches) before ReBench measures. ReBench has no
such step: its `warmup` option discards iterations inside one invocation, and
`--setup-only` runs one benchmark per executor. The wall time of each command
and its exit status go to a TSV file.

usage: prewarm.py CONFIG EXPERIMENT OUT.tsv TIMEOUT_SECONDS [REBENCH_FILTER...]
"""
import re
import subprocess
import sys
import time

import yaml

config, experiment, out_path = sys.argv[1:4]
timeout = int(sys.argv[4])
filters = sys.argv[5:]
rebench = "rebench"

with open(config) as f:
    executors = list(yaml.safe_load(f)["executors"])

with open(out_path, "w") as out:
    out.write("executor\twall_s\texit\tcommand\n")
    for executor in executors:
        plan = subprocess.run(
            [rebench, "-D", "-p", config, experiment, "e:" + executor, *filters],
            capture_output=True, text=True, check=True).stdout
        # The plan is the /usr/bin/time command; the part after the closing
        # quote of its format is the command that ReBench measures.
        commands = re.findall(r'^" (driver/run .*)$', plan, re.M)
        assert commands, "no commands in plan for " + executor
        for command in commands:
            start = time.perf_counter()
            try:
                proc = subprocess.run(
                    command, shell=True, capture_output=True,
                    timeout=timeout)
                exit_code = proc.returncode
            except subprocess.TimeoutExpired:
                exit_code = "timeout"
            wall = time.perf_counter() - start
            out.write(f"{executor}\t{wall:.3f}\t{exit_code}\t{command}\n")
            out.flush()
