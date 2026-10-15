# VM comparison on AWFY: snakebite against other VMs

This directory holds the driver that compares the snakebite bytecode VM
(`bin/sb`) with other VMs on the Are We Fast Yet benchmarks, the decisions
behind it, and the results so far. Read all of it before you run, change
or interpret anything. Everything here was measured or read from code on
2026-10-15; the evidence for each fact is given.

The native D port and its comparison with C++ are in
`benchmarks/D/results/README.md`.

## The question

How fast does the snakebite bytecode VM run D code, compared with other
VMs that run the same algorithms on the same machine? The D port is the
guest: `bin/sb` runs the same `benchmarks/D` source that ldc2 compiles.

## How to run

```
driver/build.sh            # C++ native, C++ to wasm, D GC and manual, Java jar
driver/compare.sh          # all benchmarks; results go to results/
driver/compare.sh Sieve    # one benchmark only
python3 driver/report.py   # markdown tables from results/*.data
```

- `bin/sb` is `/home/atila/coding/d/snakebite/bin/sb` unless `SB` is set.
  Use a release build (`ninja bin/sb` in the snakebite repo: ldc2
  `-release -O -flto=thin`).
- ReBench 1.4.0 is in the venv `~/.local/share/rebench-venv`.
  `compare.sh` puts it, `~/.local/bin` (wasm3) and the directory of `SB`
  on `PATH`.
- ReBench starts each command with an empty environment. `compare.sh`
  writes the environment to `.awfy-env`, and `driver/run` reads it.
  `driver/run DIR CMD...` runs `CMD` in `DIR`; with `AWFY_LOG` set it also
  appends the output, the exit status and the wall time in microseconds to
  that log, because ReBench keeps no output of a `Time` suite.
- `driver/prewarm.py` runs every command once before the measurement and
  discards the result (see "Steady state").
- A full run of both suites, 3 invocations each, takes hours. Run one
  benchmark first, look at its report, and only then run all of them.

### Machine and tools (2026-10-15)

AMD Ryzen Threadripper 1950X (16 cores, 32 threads), Linux 7.2.9-arch1-1.
LDC 1.43.0, clang 23.1.1, OpenJDK 27, node v26.11.1, Lua 5.5.1, LuaJIT
2.1.1791988261, Python 3.14.8, Wasm3 v0.9.1-beta.1 (`~/.local/bin/wasm3`,
built from source with clang -O3 and LTO).

### Executors (`compare.conf`)

| Name | What runs |
|---|---|
| C++ | `benchmarks/C++/harness`, clang++ `-O3 -flto` |
| D-gc | `benchmarks/D/harness`, ldc2 `-O3`, default GC options |
| D-gc-sbopts | the same binary with `--DRT-gcopt='cleanup:none heapSizeFactor:4'` |
| D-manual | `benchmarks/D/harness-manual` (`-d-version=ManualMemory`) |
| D-symgc | `benchmarks/D/harness-symgc --DRT-gcopt=gc:sdcq`: the D-gc build with symgc 0.0.9 |
| sb-gc | `sb -I src src -- --DRT-testmode=run-main`, in `benchmarks/D` |
| sb-manual | the same with `--version=ManualMemory`, run from `results/sb-manual` |
| sb-symgc | `env DGC=symgc sb -I src src -- --DRT-testmode=run-main`, in `benchmarks/D` |
| java-Xint, java | `java [-Xint] -cp benchmarks.jar Harness` |
| node-jitless, node | `node [--jitless] harness.js` |
| lua | PUC Lua `lua harness.lua` |
| luajit-joff, luajit | `luajit [-joff] harness.lua` |
| python3 | CPython `python3 harness.py` |
| wasm3 | `wasm3 harness.wasm`: the C++ port compiled to wasm32-wasip1 |

- wasi-sdk is not installed. `build.sh` compiles the wasm with the system
  clang and `/usr/share/wasi-sysroot`, and links
  `benchmarks/C++/wasi/throw_abort.cpp` (wasm32 has no exceptions).
- ant is not installed. `build.sh` does what the `jar` target of
  `benchmarks/Java/build.xml` does, with `javac` and `jar`.
- `java -X` says: `-Xint` "interpreted mode execution only"; the default
  `-Xmixed` is "mixed mode execution". So java-Xint never JIT-compiles.
- The interpreter-only executors are wasm3, luajit-joff, lua, java-Xint,
  node-jitless and python3. These are the fair comparison for bin/sb. The
  JIT executors (java, node, luajit) are a ceiling, not a target.

## Measurement decisions, and why

### bin/sb runs `main`, as a `-unittest` build does

`bin/sb` runs a program the way its compiled `-unittest` build runs: the
host gives it to druntime's `_d_run_main` (snakebite
`source/snakebite/druntimemain.d`). The frontend always compiles with
unit tests on (`source/snakebite/frontend/compiler.d:695`).

The D port has unit tests (`src/any.d`). A native ldc2 `-unittest` build
of the port, run as `harness-ut Sieve 2 10`, printed only "1 modules passed
unittests" and did not run `main`. With `--DRT-testmode=run-main` it ran
the benchmark. bin/sb did the same. So every bin/sb executor passes
`--DRT-testmode=run-main`.

### What "steady state" means here

Each VM is measured in its steady state: the state after its first run,
with its on-disk caches present. Java runs `.class` files that javac made
before the run; CPython writes `__pycache__/*.pyc` for the modules it
imports (seen: `benchmark`, `run`, `sieve` `.cpython-314.pyc` in
`benchmarks/Python/__pycache__`; `harness.py` is the main script and gets
none). `prewarm.py` makes these caches before the measurement.

bin/sb has no such state. Each invocation runs the D frontend and the
bytecode compiler again. Only the dependency image (native code for the
dependencies) is cached: the first run after a source change printed
`image time: 2373.3 ms`, later runs about 1 ms.

The bytecode cannot be saved to disk in its present form. Its fields hold
process addresses (snakebite `source/snakebite/backends/bytecode/vm.d`):
`Instruction.handler` is a host function pointer; branch targets are
instruction addresses; static loads and stores hold "a resolved
static-storage address, cast to a `size_t`"; a `CallSite` holds a
`prepareGuest` delegate into the compiler, a pointer to an FFI
`CallPlan`, or a builtin entry; `ExceptionHandler.type` is a
`TypeInfo_Class` pointer; `Function.signature` is a pointer.

### What bin/sb reports about itself

bin/sb prints a summary after the program (snakebite
`source/snakebite/cli.d:110-150`). Its lines do not overlap:

- `src scan`, `frontend time` (parse and semantic analysis), `image time`:
  before `main`, never inside a harness iteration.
- `compile`: the sum of the lazy bytecode compiles. They happen during the
  run, so the harness's own iteration times include them, but
  `ExecutionClock` (`source/snakebite/backends/backend.d:170-190`)
  subtracts them from bin/sb's program line (`tests and main`).
- `ModuleInfo`, `module ctors`, `tests and main`, `other`.

Measured on Mandelbrot: `compile` was 2.8 ms with 2 outer iterations and
3.1 ms with 20, the frontend about 250 ms either way. In the full `wall`
run `compile` was 2.8 to 14.0 ms per invocation, against 1 to 12 s of
execution. So the compile cannot explain bin/sb's execution times.

### GC options

bin/sb's process runs with `gc:snakebite cleanup:none heapSizeFactor:4`
(snakebite `source/snakebite/process.d:32`), and the guest allocates from
that GC. D-gc-sbopts gives native D the same options, so that only the VM
differs. D-gc keeps the defaults.

### symgc columns (D-symgc, sb-symgc)

symgc 0.0.9 (dub package `symgc`, a port of the SDC collector) is an
experimental collector. Two columns run the D port with it.

**D-symgc.** `driver/build.sh` compiles the benchmark sources with ldc2
`-O3`, as for D-gc, and the symgc 0.0.9 sources from
`~/.dub/packages/symgc/0.0.9/symgc/source` (all `.d` files except the two
Windows ones), with `--d-version=Symgc_druntime_hooks`, the version of the
dub configuration `standard`. The same command line is used by snakebite
(`dub.sdl`: `subConfiguration "symgc" "standard"`). The output is
`benchmarks/D/harness-symgc`. The symgc README says that linking
`symgc.gcobj` only registers the collector: druntime uses it only when it
gets the GC name `sdc` (prints "using SYM GC!") or `sdcq` (quiet). The
column passes `--DRT-gcopt=gc:sdcq`. A native program needs no `DGC`
variable: `DGC` is snakebite's own selector (`source/snakebite/gc.d`,
snakebite PR #743), and ordinary D programs ignore it. Without the option
the same binary uses the conservative GC. symgc is compiled in the same
mode as the program (`-O3`), as its README requires for speed.

**sb-symgc.** `env DGC=symgc sb ...`, otherwise the same command as sb-gc.
The release `bin/sb` has symgc 0.0.9 linked (`nm bin/sb` shows
`symgc.gcobj` symbols). Its C constructor reads `DGC` before druntime
starts; the value `symgc` selects the quiet `sdcq` factory, any other value
selects the conservative GC. The process options of "GC options" above
(`cleanup:none heapSizeFactor:4`) are options of the conservative GC; the
evidence below shows that the collector is symgc, so these two options do
not apply to it.

**Evidence that symgc runs.** The smallest block size differs. A guest
that calls `GC.sizeOf(GC.malloc(n))` printed (usable size in bytes):

| n | 1 | 8 | 9 | 16 | 17 | 24 | 33 |
|---|--:|--:|--:|---:|---:|---:|---:|
| native, default GC | 16 | 16 | 16 | 16 | 32 | 32 | 48 |
| native, `gc:sdcq` | 8 | 8 | 16 | 16 | 24 | 24 | 40 |
| `sb`, `DGC` unset | 16 | 16 | 16 | 16 | 32 | 32 | 48 |
| `sb`, `DGC=symgc` | 8 | 8 | 16 | 16 | 24 | 24 | 40 |

The conservative GC rounds to 16-byte classes; symgc has 8-byte classes.
Also, `harness-symgc ... --DRT-gcopt=gc:sdc` prints "using SYM GC!" and
the default run does not. (gdb did not work on `bin/sb`: it did not reach
the breakpoint in 60 s, so there is no breakpoint evidence.)

`driver/compare.sh` takes `EXECUTORS`, `RESULTS` and `SUITES` (see its
header). The symgc columns were run with `EXECUTORS="D-symgc sb-symgc"
SUITES=wall`, under `taskset -c 15` (every process of the run pinned to one
core). The other columns were not pinned (see "No CPU pinning").

### No CPU pinning

Every VM runs with its default settings and no `taskset`. Pinning starved
D's parallel GC markers in the native comparison (Storage 2190 ms against
417 ms) and would starve the JIT and GC threads of the JVM and node.

### Timers

- `wall` suite: ReBench's `Time` gauge wraps the command in
  `/usr/bin/time -f ... %e`: 10 ms resolution. `driver/run` also records
  the wall time in microseconds in `results/wall.log`.
- `iterations` suite: the harness's own per-iteration times
  (`RebenchLog` gauge).
- ReBench runs the benchmark/executor pairs in a random order. An
  interrupted run leaves scattered data, not complete benchmarks.

## Results

### Smoke run: Mandelbrot only, both suites (12:15 to 12:22)

Median of harness iterations 3-20, inner iterations 500. The data files of
this run were deleted when the full run started; the numbers are from the
report that `driver/report.py` printed then.

| Executor | ms | ÷ C++ |
|---|---:|---:|
| C++ | 39.8 | 1.00 |
| D-gc | 40.9 | 1.03 |
| D-gc-sbopts | 39.6 | 0.99 |
| D-manual | 39.7 | 1.00 |
| sb-gc | 1,034 | 25.96 |
| sb-manual | 1,046 | 26.25 |
| wasm3 | 135 | 3.40 |
| luajit-joff | 184 | 4.63 |
| lua | 462 | 11.59 |
| java-Xint | 488 | 12.25 |
| node-jitless | 820 | 20.59 |
| python3 | 1,590 | 39.91 |
| java | 40.7 | 1.02 |
| node | 39.9 | 1.00 |
| luajit | 43.3 | 1.09 |

Iteration 1 of sb-gc was 1041 ms, so there is no warm-up in bin/sb's
iterations. The bin/sb summary of that run: frontend 242 ms, compile
2.8 ms, program 1047 ms.

### Full `wall` suite: all 14 benchmarks (12:26 to 12:45)

One invocation per measurement, 1 outer iteration, 3 invocations, after a
discarded pre-run. No failures. Data: `driver/data/2026-10-15/wall.data`,
`wall.log`, `prewarm.tsv`.

The table gives the harness's own time for the one iteration (median of 3
invocations), bin/sb's as a ratio to each other executor. This is a first
iteration: for bin/sb it includes the lazy compile (at most 14 ms, see
above); for the JIT executors it includes warm-up, so they are not in the
table.

| Benchmark | sb-gc ms | ÷ D-gc | ÷ D-manual | ÷ C++ | ÷ wasm3 | ÷ luajit-joff | ÷ lua | ÷ java-Xint | ÷ node-jitless | ÷ python3 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| DeltaBlue | 1,192 | 29.6 | 52.5 | 42.6 | 4.2 | 1.5 | 1.1 | 1.8 | 2.0 | 1.6 |
| Richards | 12,031 | 146.9 | 146.9 | 128.4 | 9.9 | 3.2 | 2.1 | 2.4 | 2.1 | 2.0 |
| Json | 1,534 | 32.1 | 37.4 | 30.7 | 2.3 | 2.1 | 1.2 | 0.3 | 1.5 | 1.4 |
| CD | 3,385 | 41.2 | 56.9 | 70.2 | 6.4 | 1.9 | 1.1 | 2.0 | 1.3 | 1.0 |
| Havlak | 4,454 | 17.4 | 47.4 | 40.5 | 2.9 | 1.0 | 0.6 | 1.6 | 1.4 | 1.0 |
| Bounce | 1,484 | 63.1 | 47.9 | 53.2 | 6.1 | 2.1 | 1.0 | 2.5 | 0.9 | 0.8 |
| List | 3,978 | 88.6 | 93.6 | 117.7 | 11.1 | 7.5 | 4.4 | 2.2 | 4.8 | 3.8 |
| Mandelbrot | 1,034 | 21.2 | 21.0 | 24.1 | 7.5 | 5.2 | 2.2 | 2.1 | 1.2 | 0.6 |
| NBody | 1,409 | 58.2 | 82.9 | 44.4 | 6.1 | 2.7 | 1.5 | 0.8 | 0.9 | 0.7 |
| Permute | 2,830 | 74.3 | 92.2 | 110.1 | 8.5 | 4.4 | 2.2 | 4.0 | 1.5 | 1.3 |
| Queens | 1,960 | 106.5 | 80.3 | 202.1 | 10.4 | 4.4 | 2.4 | 3.9 | 1.7 | 1.9 |
| Sieve | 2,550 | 60.7 | 63.0 | 85.6 | 6.7 | 4.5 | 3.2 | 3.4 | 1.9 | 0.9 |
| Storage | 7,591 | 14.8 | 23.5 | 27.8 | 3.8 | 6.5 | 3.9 | 5.4 | 7.9 | 4.2 |
| Towers | 3,490 | 147.9 | 122.0 | 132.2 | 11.3 | 5.2 | 2.8 | 3.2 | 2.0 | 2.4 |
| **Geomean** | | **50.6** | **60.1** | **64.7** | **6.3** | **3.2** | **1.9** | **2.1** | **1.8** | **1.4** |

A value above 1 means bin/sb is slower. bin/sb is slower than every
interpreter-only VM on the geometric mean, CPython included: 1.9x PUC Lua,
2.1x `java -Xint`, 6.3x wasm3. `java -Xint` and PUC Lua are close to each
other on Mandelbrot (488 and 462 ms), although Java is statically typed.

bin/sb per invocation in this run: frontend 236 to 284 ms, image 0.9 ms,
compile 2.8 to 14.0 ms. sb-manual is slower than sb-gc on Havlak (5,979
against 4,454 ms) and Storage (9,516 against 7,591 ms); this difference
also shows that `--version=ManualMemory` selects other code.

The wall times of whole invocations are in `wall.log` and in the report.
They include each VM's startup (for bin/sb: the frontend) and are not the
comparison of execution speed.

### Full `wall` suite: the symgc columns (D-symgc, sb-symgc)

Only the two symgc executors were run, on the same 14 benchmarks with the
same arguments, 1 outer iteration, 3 invocations, after a discarded
pre-run (`EXECUTORS="D-symgc sb-symgc" SUITES=wall`). Every process was
pinned with `taskset -c 15`, and other jobs ran on the machine at the same
time. The existing columns above were not re-run: their numbers are kept
and the ratios below use them (sb-gc is the sb-gc column of the table
above). Data: `driver/data/2026-10-15/symgc-wall.data`, `symgc-wall.log`,
`symgc-prewarm.tsv`, and `symgc-rerun-wall.data`, `symgc-rerun-wall.log`.

| Benchmark | D-symgc ms | sb-symgc ms | sb-gc ÷ D-symgc | sb-gc ÷ sb-symgc |
|---|---:|---:|---:|---:|
| DeltaBlue | 27.1 | 1,024 | 43.9 | 1.16 |
| Richards | 81.8 | 11,144 | 147.1 | 1.08 |
| Json | 32.7 | 1,548 | 46.9 | 0.99 |
| CD | 85.9 | 3,142 | 39.4 | 1.08 |
| Havlak | 146.9 | 4,222 | 30.3 | 1.05 |
| Bounce | 23.4 | 1,387 | 63.5 | 1.07 |
| List | 33.9 | 3,131 | 117.4 | 1.27 |
| Mandelbrot | 43.3 | 434 | 23.9 | 2.39 |
| NBody | 17.3 | 1,115 | 81.6 | 1.26 |
| Permute | 32.1 | 3,158 | 88.3 | 0.90 |
| Queens | 18.8 | 2,303 | 104.5 | 0.85 |
| Sieve | 44.7 | 2,051 | 57.0 | 1.24 |
| Storage | 658.8 | 10,285 | 11.5 | 0.74 |
| Towers | 17.6 | 2,933 | 197.9 | 1.19 |
| **Geomean** | | | **59.1** | **1.12** |

Times are the harness's own time for the one iteration, median of 3. A
value above 1 means sb-gc is slower. For comparison, D-gc was 25 to 512 ms
(sb-gc ÷ D-gc geomean 50.6). On the D port, D-symgc ÷ D-gc has geomean
0.86: faster on Havlak (147 against 256 ms) and DeltaBlue, slower on
Storage (659 against 512 ms).

**Failures.** None under symgc. The first pass recorded two failed
invocations: D-symgc Bounce (exit 1, no output, after 27 ms) and sb-symgc
Permute (exit 1, no output, after 2.9 s). They did not reproduce: 100
further runs of `harness-symgc Bounce` and 6 of sb-symgc Permute all
passed. The temporary file system was full for this user (EDQUOT: the
tools reported "disk quota is full") in the same period, and `driver/run`
writes the output to a temporary file, so we take it as the cause; we did
not prove it. Both pairs were run again (3 invocations each, no failure);
the numbers above come from the second run. The first-pass log entries are
in `symgc-wall.log`.

**The sb-gc column is older than the sb-symgc column.** The sb-gc numbers
come from the `bin/sb` of the first run. The sb-symgc run used the
current release `bin/sb` of snakebite master (it includes PR #744, which
inlines three-address handlers). The two ratios in the last column
therefore mix a collector change with a `bin/sb` change. A control with
the current `bin/sb` and pinned, harness time per iteration, 3 runs each:

| Benchmark | sb-gc (this README) | `bin/sb` now, no `DGC` | `bin/sb` now, `DGC=symgc` |
|---|---:|---:|---:|
| Mandelbrot | 1,034 | 401 to 423 | 423 to 432 |
| DeltaBlue | 1,192 | 1,041 to 1,058 | 1,017 to 1,030 |
| Sieve | 2,550 | 2,122 to 2,478 | 2,015 to 2,208 |
| Towers | 3,490 | 2,966 to 3,059 | 2,824 to 2,911 |

With the same binary, symgc changes the time of these four by -8 % to +5 %
(Mandelbrot +3 %). So the Mandelbrot ratio of 2.39 is the `bin/sb`
change, not symgc. The control covers four benchmarks only. A fair sb-gc ÷ sb-symgc needs a
full re-run of sb-gc with the current `bin/sb`.

### `iterations` suite: incomplete, do not use

The full run was stopped during the `iterations` suite. Because of the
random order, most pairs have no data. From about 13:19 a profiling build
of snakebite ran on the same machine, so data from then on is disturbed.
`driver/data/2026-10-15/iterations.data` is kept only as a record.

## Why bin/sb is slow

Measured on Mandelbrot by a profiler run on 2026-10-15; the full record,
commands and raw counts are on snakebite issue #720
(https://github.com/atilaneves/snakebite/issues/720#issuecomment-6191493860).

Per inner Mandelbrot iteration, frontend and start-up removed:

| VM | Bytecodes | Machine instructions | Per bytecode | Cycles |
|---|---:|---:|---:|---:|
| bin/sb (release) | 57 | 1073 | 18.8 | 502 |
| lua | 13 | 456 | 35.1 | 222 |
| java -Xint | 35 | 311 | 8.9 | 237 |
| wasm3 | not known | 138 | not known | 65 |

- bin/sb executes too many bytecode instructions: 4.4x Lua's count and
  1.6x Java's. 40 of the 57 only move data (frame copies, frame
  addresses, indirect loads and stores); 11 do arithmetic or compares,
  6 do control flow.
- The bytecode compiler makes them. `compileBinary` (snakebite
  `source/snakebite/backends/bytecode/compiler.d:5516`) evaluates each
  operand into a new temporary and copies the result out.
  `compileAssign` (`compiler.d:2836`) writes a plain local through
  `opFrameAddress` + `opStoreIndirect`, not to its frame slot.
- The cost per bytecode is moderate: 18.8 machine instructions, about
  half of Lua's.
- The release build mispredicts more indirect branches than the same
  source with `--frame-pointer=all -g` (4.33 against 2.41 per
  iteration) and is slower (1041 against 874 ms per harness iteration).
  The cause is under investigation; the result goes to #720.
- The bytecode optimisations of the week before (snakebite PRs #724,
  #725, #731, #734, #736) made handlers cheaper and fused some pairs.
  They were chosen and measured on the Cerealed test suite, a call- and
  copy-heavy workload, and did not change the number of bytecodes the
  compiler makes for an arithmetic loop.

## Lessons from running this

- Run one benchmark, look at its report and stop; run all of them only
  after the one-benchmark report is checked.
- Do not wait on an output format you have not checked: zsh's `time`
  prints `... total`, not a line that starts with `real`. An agent waited
  11 minutes on a run that had ended.
- Do not run builds or other benchmarks while a measurement runs.
- `.gitignore` ignores `*.md`. Add markdown files with `git add -f`.
