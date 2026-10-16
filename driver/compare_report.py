#!/home/atila/.local/share/rebench-venv/bin/python3
"""Before/after tables from two wall.data files.
usage: compare_report.py BEFORE_DIR AFTER_DIR"""
import sys, statistics as st, math
from collections import defaultdict
def rd(p):
    d = defaultdict(list)
    for l in open(p):
        if l.startswith("#") or l.startswith("invocation"): continue
        c = l.rstrip("\n").split("\t")
        if c[4] == "total": d[(c[6], c[5])].append(float(c[2]))
    return d
B, A = rd(sys.argv[1] + "/wall.data"), rd(sys.argv[2] + "/wall.data")
bench = sorted({b for _, b in A})
cols = ["D-gc","D-symgc","sb-symgc","C++","lua","luajit-joff","luajit","java-Xint","java","node-jitless","node","wasm3","python3"]
m = lambda d, e, b: st.median(d[(e, b)]) if len(d.get((e, b), [])) == 3 else None
f = lambda x: "n/a" if x is None else f"{x:,.0f}"
print("| benchmark | sb-gc before | sb-gc after | after/before |"); print("|---|--:|--:|--:|")
rs = []
for b in bench:
    x, y = m(B, "sb-gc", b), m(A, "sb-gc", b)
    r = y / x if x and y else None
    if r: rs.append(r)
    print(f"| {b} | {f(x)} | {f(y)} | {r:.3f} |" if r else f"| {b} | {f(x)} | {f(y)} | n/a |")
print(f"| geomean | | | {math.exp(sum(map(math.log, rs))/len(rs)):.3f} |")
print("\n| benchmark | sb-gc | " + " | ".join(cols) + " |"); print("|---|" + "--:|" * (len(cols) + 1))
for b in bench: print(f"| {b} | {f(m(A,'sb-gc',b))} | " + " | ".join(f(m(A, e, b)) for e in cols) + " |")
print("\n| executor | n | geomean sb-gc after / executor | geomean sb-gc before / executor |"); print("|---|--:|--:|--:|")
for e in cols:
    pa, pb = [], []
    for b in bench:
        o, a, bf = m(A, e, b), m(A, "sb-gc", b), m(B, "sb-gc", b)
        if o and a and bf: pa.append(a / o); pb.append(bf / o)
    g = lambda p: math.exp(sum(map(math.log, p)) / len(p)) if p else float("nan")
    print(f"| {e} | {len(pa)} | {g(pa):.2f} | {g(pb):.2f} |")
print("\nMissing cells (after run):")
for e in ["sb-gc"] + cols:
    miss = [b for b in bench if m(A, e, b) is None]
    n = {b: len(A.get((e, b), [])) for b in bench}
    if miss: print(f"- {e}: " + ", ".join(f"{b} ({n[b]}/3)" for b in miss))
print("benchmarks:", len(bench))
