#!/home/atila/.local/share/rebench-venv/bin/python3
"""Turn results/ into markdown tables.

Inputs (all written by driver/compare.sh):
  results/wall.data        ReBench data of suite `wall` (Time adapter)
  results/wall.log         output of each `wall` invocation, from driver/run
  results/iterations.data  ReBench data of suite `iterations` (RebenchLog)
  compare.conf             executor and benchmark names, and arguments

usage: report.py [RESULTS_DIR] > report.md
"""
import re
import statistics
import sys
from collections import defaultdict

import yaml

results = sys.argv[1] if len(sys.argv) > 1 else "results"
with open("compare.conf") as f:
    conf = yaml.safe_load(f)
executors = list(conf["executors"])
benchmarks = [list(b)[0] for b in conf["benchmark_suites"]["wall"]["benchmarks"]]
norm = lambda s: s.replace("'", "").split()
exec_tokens = {e: norm(conf["executors"][e]["args"]) for e in executors}


def read_data(path):
    """Return rows of (invocation, iteration, value, criterion, benchmark, executor)."""
    rows = []
    with open(path) as f:
        for line in f:
            if line.startswith("#") or line.startswith("invocation"):
                continue
            c = line.rstrip("\n").split("\t")
            rows.append((int(c[0]), int(c[1]), float(c[2]), c[4], c[5], c[6]))
    return rows


def read_log(path):
    """Return {(executor, benchmark): [ {exit, wall_us, lines} ... ]} in order."""
    out = defaultdict(list)
    cur = None
    with open(path) as f:
        for line in f:
            if line.startswith("### exit "):
                p = line.split()
                cur["exit"], cur["wall_us"] = int(p[2]), int(p[4])
                tokens = cur["cmd"]
                best = None
                for e in executors:
                    t = exec_tokens[e]
                    if tokens[: len(t)] == t and (best is None or len(t) > len(exec_tokens[best])):
                        best = e
                bench = tokens[len(exec_tokens[best])]
                out[(best, bench)].append(cur)
                cur = None
            elif line.startswith("### "):
                cur = {"cmd": norm(line[4:]), "lines": []}
            elif cur is not None:
                cur["lines"].append(line.rstrip("\n"))
    return out


med = lambda xs: statistics.median(xs) if xs else None
harness_re = re.compile(r"^\S+: iterations=\d+ runtime: ([0-9.]+)(u|m)s")
sb_keys = ["src scan", "frontend time", "image time", "backend latency", "compile",
           "ModuleInfo", "module ctors", "tests and main", "other"]


def harness_ms(lines):
    ms = []
    for l in lines:
        m = harness_re.match(l)
        if m:
            ms.append(float(m.group(1)) / (1000 if m.group(2) == "u" else 1))
    return ms


def sb_summary(lines):
    d = {}
    for l in lines:
        m = re.match(r"^\s*(src scan|frontend time|image time|backend latency|compile|ModuleInfo"
                     r"|module ctors|tests and main|other):\s*([0-9.]+) ms", l)
        if m:
            d[m.group(1)] = float(m.group(2))
    return d


wall_rows = read_data(f"{results}/wall.data")
iter_rows = read_data(f"{results}/iterations.data")
log = read_log(f"{results}/wall.log")

wall = defaultdict(list)       # ReBench Time wall, ms
rss = defaultdict(list)
for inv, it, v, crit, b, e in wall_rows:
    (wall if crit == "total" else rss)[(e, b)].append(v)
iters = defaultdict(lambda: defaultdict(list))   # (e,b) -> invocation -> [ms]
for inv, it, v, crit, b, e in iter_rows:
    if crit == "total":
        iters[(e, b)][inv].append(v)

cell = {}
for e in executors:
    for b in benchmarks:
        k = (e, b)
        c = {}
        if wall[k]:
            c["wall"] = med(wall[k])
        runs = [r for r in log.get(k, []) if r["exit"] == 0]
        if runs:
            c["wrap"] = med([r["wall_us"] / 1000 for r in runs])
            sums = [sum(harness_ms(r["lines"])) for r in runs]
            c["sum"] = med(sums)
            if e.startswith("sb-"):
                parts = [sb_summary(r["lines"]) for r in runs]
                c["sb"] = {p: med([x[p] for x in parts if p in x]) for p in sb_keys}
        if iters[k]:
            c["iter1"] = med([v[0] for v in iters[k].values() if v])
            c["itermed"] = med([x for v in iters[k].values() for x in v[2:]])
            c["n_iter"] = sorted(len(v) for v in iters[k].values())
        if "wall" in c and "sum" in c:
            c["startup"] = c["wall"] - c["sum"]
        if "wrap" in c and "sum" in c:
            c["startup_wrap"] = c["wrap"] - c["sum"]
        cell[k] = c


def fmt(x, digits=1):
    if x is None:
        return "n/a"
    return f"{x:,.{digits}f}" if abs(x) < 100 else f"{x:,.0f}"


def table(title, getter, rows=benchmarks, cols=executors, digits=1):
    print(f"\n### {title}\n")
    print("| benchmark | " + " | ".join(cols) + " |")
    print("|---|" + "---:|" * len(cols))
    for b in rows:
        print(f"| {b} | " + " | ".join(fmt(getter(e, b), digits) for e in cols) + " |")


def get(key):
    return lambda e, b: cell[(e, b)].get(key)


def ratio(key, ref):
    def g(e, b):
        x, r = cell[(e, b)].get(key), cell[(ref, b)].get(key)
        return None if x is None or not r else x / r
    return g


print("# AWFY VM comparison\n")
print("All times are milliseconds (ms). Each cell is the median over the invocations.")
print("`n/a` means no successful measurement (see the failures list).")
table("Wall time of one invocation, 1 outer iteration (ReBench Time adapter, ms; resolution 10 ms)", get("wall"))
table("Wall time of one invocation, measured by driver/run (ms)", get("wrap"))
table("Harness iteration 1 (suite iterations, ms)", get("iter1"))
table("Sum of harness iteration times in the 1-iteration run (suite wall, ms)", get("sum"))
table("Startup = ReBench wall time - harness sum (ms)", get("startup"))
table("Startup = driver/run wall time - harness sum (ms)", get("startup_wrap"))
table("Median of harness iterations 3-20 (suite iterations, ms)", get("itermed"))
for ref in ("C++", "D-gc", "D-manual"):
    table(f"Ratio of ReBench wall time to {ref}", ratio("wall", ref), digits=2)
for ref in ("C++", "D-gc", "D-manual"):
    table(f"Ratio of iteration 3-20 median to {ref}", ratio("itermed", ref), digits=2)

print("\n### bin/sb summary per invocation (ms, median over the invocations)\n")
print("| benchmark | executor | " + " | ".join(sb_keys) + " |")
print("|---|---|" + "---:|" * len(sb_keys))
for b in benchmarks:
    for e in ("sb-gc", "sb-manual"):
        s = cell[(e, b)].get("sb")
        if s:
            print(f"| {b} | {e} | " + " | ".join(fmt(s[p]) for p in sb_keys) + " |")

print("\n### Failures and incomplete data\n")
nfail = 0
for e in executors:
    for b in benchmarks:
        k = (e, b)
        bad = [r for r in log.get(k, []) if r["exit"] != 0]
        for r in bad:
            nfail += 1
            tail = " / ".join(l for l in r["lines"] if l.strip())[-300:]
            print(f"- wall {e} {b}: exit {r['exit']}: {tail}")
        if len(wall[k]) != 3:
            print(f"- wall {e} {b}: {len(wall[k])} of 3 invocations recorded")
        n = cell[k].get("n_iter")
        if n != [20, 20, 20]:
            print(f"- iterations {e} {b}: iteration counts per invocation: {n}")
print(f"\n(failed log entries: {nfail})")
