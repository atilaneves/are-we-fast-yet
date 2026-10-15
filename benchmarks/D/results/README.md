# D port of Are We Fast Yet: native results against C++

This directory records how the D port of the Are We Fast Yet (AWFY)
benchmarks compares with the upstream C++ port, when both are compiled
natively. It also records each defect that was found in the D port and
how it was found.

The port exists so that the snakebite bytecode VM can be compared with
other VMs (wasm3, `java -Xint`, `node --jitless`, Lua, LuaJIT, CPython)
on a known suite. Before the VM numbers mean anything, natively compiled
D must perform like natively compiled C++ on the same benchmarks.
Otherwise a slow benchmark measures the port, not the VM.

## Summary

- The final D port, with manual memory management, is at C++ speed or
  faster on 10 of the 14 benchmarks. The remaining gaps are Queens
  (1.48x), Storage (1.17x), List (1.15x) and CD (1.13x). Queens and List
  were not investigated.
- With the GC, D is slower than C++ on the allocation-heavy benchmarks:
  Havlak 2.35x, DeltaBlue 2.08x, Storage 1.81x, Queens 1.64x and CD
  1.57x.
- The first port was not faithful, although every benchmark passed. Four
  kinds of defect made it slower than necessary:
  1. classes for types that need no runtime polymorphism;
  2. `==` on class references, where C++ compares pointers;
  3. the wrong free order in Storage, which made glibc trim the heap and
     fault it back in on every iteration;
  4. a generic template instead of `std::any`.
- Two ideas from the standard library did not work. `std.variant.Variant`
  is 48 bytes. `VariantN!8` is 16 bytes but 16-byte aligned, and it made
  the Storage GC build run one collection per inner iteration. A small
  `Any` modelled on libstdc++ `std::any` fixed both problems.
- NBody in D is twice as fast as C++ (0.47x) after `Body` became a
  struct. The result is correct (the benchmark checks the exact energy
  value). The reason was not investigated.

## Setup

| Item | Value |
| --- | --- |
| CPU | AMD Ryzen Threadripper 1950X, 16 cores, 32 threads |
| Memory | 64 GB |
| Kernel | Linux 7.2.9 (Arch), `schedutil` governor |
| libc | glibc 2.44 |
| D compiler | LDC 1.43.0 (DMD front end 2.113.0, LLVM 22.1.8) |
| C++ compiler | clang 23.1.1 |
| AWFY upstream | smarr/are-we-fast-yet at 74306fe |

Both languages use the LLVM back end, at the system versions. No
version-matched clang was installed: the comparison uses the compilers
that a user of this machine has.

Build commands:

```sh
# C++ (benchmarks/C++)
CXX=clang++ OPT='-O3 -flto' ./build.sh

# D with the GC (benchmarks/D)
ldc2 -O3 -release -boundscheck=off -flto=thin -gcc=clang \
    -Isrc src/*.d src/som/*.d -of=harness-release -od=build-release

# D with manual memory management
ldc2 -O3 -release -boundscheck=off -flto=thin -gcc=clang \
    -d-version=ManualMemory \
    -Isrc src/*.d src/som/*.d \
    -of=harness-manual-release -od=build-manual-release
```

`-gcc=clang` is necessary for LTO linking with LDC. C++ does not use
`-march=native` (the upstream default), and D does not use `-mcpu=native`.

Run parameters: the AWFY steady-state inner iterations (DeltaBlue 12000,
Richards 100, Json 100, CD 250, Havlak 1500, Bounce 1500, List 1500,
Mandelbrot 500, NBody 250000, Permute 1000, Queens 1000, Sieve 3000,
Storage 1000, Towers 600), 20 outer iterations, 3 invocations per
binary. A value is the median over outer iterations 3 to 20, then the
median of the 3 invocations. The runs alternate between the binaries,
benchmark by benchmark.

No CPU pinning. Every program runs with its default settings. With
`taskset` pinning to one core, D's parallel GC markers starved: Storage
took 2190 ms pinned, against 417 ms unpinned. Pinning would also starve
the JVM and V8 GC and JIT threads in the VM comparison.

The first run used ReBench 1.4.0 (`data/r0-rebench.conf`). The later
runs used `tools/compare.sh`, a loop around the harness with the same
parameters. It does not check exit codes. Each build was checked
separately: all 14 benchmarks exit 0 (a wrong result exits non-zero).

Noise: the same binary can differ by up to about 20% between runs on
this machine. Sieve shows this best. It has the same code in the GC and
manual variants, and in different runs the two variants swapped
places, at 1.0x and 1.2x C++. Treat a difference under about 10% in one
run as noise.

## The port

- One D source tree, two variants:
  - GC (default): `new`, no frees.
  - `version(ManualMemory)`: `malloc`/`free` through `src/memory.d`
    (`make`, `makePtr`, `makeArray`, `dispose`), and a destructor or
    `scope` wherever C++ uses `delete` or RAII.
- The manual variant was checked in two ways:
  - The GC allocates zero bytes in every benchmark.
  - ASan and LSan report zero errors and zero leaks for all 14
    benchmarks.
- Known deviations from the C++ port:
  - CD frees removed red-black tree nodes. The C++ port leaks them.
  - DeltaBlue `Sym` objects are module-level values.
  - The harness and some benchmarks use `std.stdio`/`std.conv` for
    output.
  - `Element` in Storage holds a D slice (16 bytes), where C++ holds a
    pointer (8 bytes) and `new[]` keeps the length in a hidden header.

## What was found, in order

### 1. First native comparison

The first native comparison came from the first faithful-looking port
(`d-port` up to 5a64887), using ReBench. Median ms; the C++ column is
the reference.

| Benchmark | C++ | D GC | D manual | GC / C++ | manual / C++ |
| --- | --- | --- | --- | --- | --- |
| Bounce | 25.7 | 21.0 | 20.8 | 0.82 | 0.81 |
| CD | 40.3 | 71.7 | 49.0 | 1.78 | 1.21 |
| DeltaBlue | 17.5 | 55.3 | 17.3 | 3.17 | 0.99 |
| Havlak | 99.5 | 496.6 | 149.6 | 4.99 | 1.50 |
| Json | 42.7 | 39.1 | 36.3 | 0.92 | 0.85 |
| List | 24.8 | 28.3 | 31.0 | 1.14 | 1.25 |
| Mandelbrot | 40.4 | 40.4 | 39.9 | 1.00 | 0.99 |
| NBody | 23.5 | 21.3 | 21.6 | 0.91 | 0.92 |
| Permute | 17.4 | 18.3 | 17.6 | 1.05 | 1.01 |
| Queens | 9.3 | 14.0 | 13.4 | 1.51 | 1.44 |
| Richards | 90.6 | 79.5 | 72.8 | 0.88 | 0.80 |
| Sieve | 27.5 | 27.4 | 27.6 | 1.00 | 1.00 |
| Storage | 275.1 | 495.9 | 489.1 | 1.80 | 1.78 |
| Towers | 15.5 | 16.4 | 16.7 | 1.06 | 1.08 |

### 2. Havlak with the GC: the gap is the GC, not the algorithm

The GC variant of Havlak was 5x C++. GC options showed where the time
went:

| Havlak, D GC variant | ms |
| --- | --- |
| default | 487 |
| `--DRT-gcopt=parallel:0` | 268 |
| `--DRT-gcopt=disable:1` | 214 |
| C++ | 103 |

With collections disabled, a `perf` profile showed that the benchmark's
own functions take the same absolute time in D and C++ (for example,
`findLoops` is about 11 ms in both). About 56% of the D samples were
in GC allocation, against about 18% in `malloc` plus `free` for C++. So
the algorithm was ported correctly, and the gap is the cost of
allocation.

Parallel marking made it worse here: the default parallel mark is
almost twice as slow as `parallel:0` for this heap.

### 3. Storage: the order of `free` decides whether glibc trims

With manual memory, Storage was still 1.78x C++. `perf stat` showed that
the user-mode time was almost the same. The difference was the kernel:

| Storage | page faults | system time |
| --- | --- | --- |
| C++ | 223 | 0.002 s |
| D manual | 460,167 | 0.81 s |

`strace` showed about 5 `brk` calls per inner iteration in D. glibc
shrank the heap after each tree was freed, and the next tree faulted
the pages in again. With
`GLIBC_TUNABLES=glibc.malloc.trim_threshold=1073741824`, D took 327 ms
with 258 page faults.

The first hypothesis was the block size: a D slice is 16 bytes and a
C++ pointer is 8. A direct test disproved it:

| Variant | ms | page faults (20 x 1000 iterations) |
| --- | --- | --- |
| C++ | 283 | 223 |
| C++ with a 16-byte element | 288 | 274 |
| D, slice element | 525 | 1,840,166 |
| D, C++ layout (pointer + length header) | 346 | 920,163 |

An `LD_PRELOAD` shim (`tools/malloc-histogram.c`) counted every `malloc`
and every `free` that shrank the heap:

- D (with the C++ layout) and C++ made exactly the same `malloc`
  requests, with the same sizes and the same counts.
- In D, 2 frees of a 40-byte block per inner iteration shrank the heap.
  In C++, no free did.
- `strace -k` put the `brk` calls inside `free`, called from the D
  `disposeTree`.

The difference is the free order. C++ `delete[]` destroys array
elements last to first. The D port freed them first to last. glibc 2.44
has no fastbins (`global_max_fast` and `have_fastchunks` do not exist
in it), and its tcache holds 16 blocks per size class:

- In C++ order, the blocks highest in the heap are freed first. They go
  into the tcache and stay allocated as far as the heap is concerned, so
  the rest of the freed tree cannot merge into the top chunk.
- In D order, the highest blocks are freed last. The tcache is full by
  then, so they merge with their neighbours and with the top chunk.
  The top chunk goes over the trim threshold, and `free` gives the
  memory back to the kernel.

`foreach_reverse` in `disposeTree` fixed it (28c5b5f):

| Storage, reverse free order | ms | page faults |
| --- | --- | --- |
| C++ | 283 | 225 |
| D, slice element | 337 | 259 |
| D, C++ layout | 248 | 209 |

The rest of the Storage gap (1.17x) is the 16-byte slice element. With
the C++ layout, D is faster than C++.

### 4. Classes for types that need no runtime polymorphism

In D, a class is for runtime polymorphism. The first port used classes
for `Vector`, `Set`, the Havlak and CD types and others. In C++ these
have no virtual functions, and C++ holds many of them by value. In D
they became separate heap objects with virtual methods (D class methods
are virtual unless `final`), and each one had a vtable pointer and a
monitor field.

A first experiment made only the `Vector` and `Set` methods final:

| Benchmark | manual before | manual final |
| --- | --- | --- |
| Havlak | 157.2 | 130.0 |
| DeltaBlue | 17.8 | 16.1 |

Then two commits converted the types:

- da2eb98: every type that C++ holds by value is a D struct held by
  value. `IdentitySet : Set` and DeltaBlue `Plan : Vector` inherit only
  to reuse code in C++; in D they use composition with `alias this`.
- d01bc28: every type that C++ creates with `new` and that has no
  virtual function is a D struct on the heap, held by pointer
  (`Element`, `TowersDisk`, the Havlak graph nodes, `Strength`, the
  red-black tree node).

The classes that remain all have a C++ counterpart with a virtual
function (the `Benchmark` base, DeltaBlue constraints, Json values,
`Dictionary` entries, and the Richards types through the virtual
destructor of `TrackedObject`), or they are exceptions.

### 5. `==` on class references is not pointer equality

C++ `Set::contains` compares pointers, or calls `equal` for pointer
types. In D, `==` on class references calls `object.opEquals`, which is
a function call with a virtual call inside it. The port now does what
C++ does: it calls `equal` where C++ calls `equal`, and uses `is` where
C++ compares pointers.

### 6. `std::any`

The C++ harness returns results as `std::any`, and List stores
`std::any` in each `Element`. The first port used a template
(`Benchmark!R`) and an `int`, which removes the type erasure that C++
pays for. Getting the same cost in D took two tries:

| Type | size | alignment | notes |
| --- | --- | --- | --- |
| libstdc++ `std::any` | 16 | 8 | manager pointer + 8-byte buffer |
| `std.variant.Variant` | 48 | 16 | storage sized for the largest supported type |
| `std.variant.VariantN!8` | 16 | 16 | open `VariantN` aligns to `real.alignof` (std/variant.d:142, :221) |
| `Any` in `src/any.d` | 16 | 8 | copy of the libstdc++ design |

With `VariantN!8`, `Element` was 32 bytes instead of 24. Also, the GC
variant of Storage ran one collection per inner iteration (5000
collections, against 716) and took 652 ms instead of 497 ms. The cause
of the extra collections was not investigated, because the replacement
removed them.

`src/any.d` copies libstdc++:

- A manager function pointer, and a union of one `void*` and an 8-byte
  buffer.
- Values that fit in 8 bytes and can be moved bit by bit are stored
  inline. Other values go on the heap.
- `get!T` checks the type by comparing the manager pointer, as
  `std::any_cast` does.
- `const` is removed from the stored type, as `std::any` does.
- It does not use `TypeInfo`.

The 8 bytes saved per `Element` made no measurable difference to List.

## Final results

`d-port` at ced0b46. Median ms; the ratios are D divided by C++.

| Benchmark | C++ | D GC | D manual | GC / C++ | manual / C++ |
| --- | --- | --- | --- | --- | --- |
| Bounce | 26.1 | 23.3 | 23.5 | 0.89 | 0.90 |
| CD | 40.1 | 63.0 | 45.4 | 1.57 | 1.13 |
| DeltaBlue | 16.5 | 34.4 | 14.8 | 2.08 | 0.90 |
| Havlak | 99.0 | 232.5 | 80.1 | 2.35 | 0.81 |
| Json | 44.7 | 35.6 | 31.7 | 0.80 | 0.71 |
| List | 25.3 | 29.5 | 29.0 | 1.17 | 1.15 |
| Mandelbrot | 40.2 | 40.2 | 41.4 | 1.00 | 1.03 |
| NBody | 23.6 | 11.1 | 11.0 | 0.47 | 0.47 |
| Permute | 17.4 | 18.9 | 17.8 | 1.09 | 1.02 |
| Queens | 9.2 | 15.1 | 13.6 | 1.64 | 1.48 |
| Richards | 90.0 | 74.1 | 70.9 | 0.82 | 0.79 |
| Sieve | 27.9 | 27.4 | 33.5 | 0.98 | 1.20 |
| Storage | 274.0 | 497.0 | 320.1 | 1.81 | 1.17 |
| Towers | 15.7 | 17.1 | 15.5 | 1.09 | 0.99 |

Geometric mean of the ratios over the 14 benchmarks: GC 1.17, manual
0.95.

### Ratio to C++ after each step

Each column is a separate run, so the noise described above applies
between columns. The first column is the ReBench run from section 1.

Manual memory:

| Benchmark | first port | free order | value structs | heap structs | `Any` |
| --- | --- | --- | --- | --- | --- |
| Bounce | 0.81 | 0.90 | 0.80 | 0.86 | 0.90 |
| CD | 1.21 | 1.26 | 1.20 | 1.09 | 1.13 |
| DeltaBlue | 0.99 | 0.97 | 0.80 | 0.89 | 0.90 |
| Havlak | 1.50 | 1.52 | 0.80 | 0.82 | 0.81 |
| Json | 0.85 | 0.89 | 0.76 | 0.76 | 0.71 |
| List | 1.25 | 1.12 | 1.28 | 1.13 | 1.15 |
| Mandelbrot | 0.99 | 0.95 | 0.98 | 0.97 | 1.03 |
| NBody | 0.92 | 0.93 | 0.47 | 0.48 | 0.47 |
| Permute | 1.01 | 1.03 | 1.02 | 1.02 | 1.02 |
| Queens | 1.44 | 1.36 | 1.30 | 1.40 | 1.48 |
| Richards | 0.80 | 0.88 | 0.85 | 0.87 | 0.79 |
| Sieve | 1.00 | 1.21 | 1.23 | 0.91 | 1.20 |
| Storage | 1.78 | 1.17 | 1.16 | 1.23 | 1.17 |
| Towers | 1.08 | 1.06 | 0.99 | 1.00 | 0.99 |

GC:

| Benchmark | first port | free order | value structs | heap structs | `Any` |
| --- | --- | --- | --- | --- | --- |
| Bounce | 0.82 | 0.82 | 0.88 | 0.80 | 0.89 |
| CD | 1.78 | 1.82 | 1.63 | 1.48 | 1.57 |
| DeltaBlue | 3.17 | 2.54 | 1.99 | 2.05 | 2.08 |
| Havlak | 4.99 | 4.83 | 2.26 | 2.23 | 2.35 |
| Json | 0.92 | 0.90 | 0.82 | 0.84 | 0.80 |
| List | 1.14 | 1.17 | 1.12 | 1.24 | 1.17 |
| Mandelbrot | 1.00 | 0.95 | 0.99 | 1.00 | 1.00 |
| NBody | 0.91 | 0.94 | 0.47 | 0.48 | 0.47 |
| Permute | 1.05 | 1.04 | 1.12 | 1.09 | 1.09 |
| Queens | 1.51 | 1.77 | 1.77 | 1.70 | 1.64 |
| Richards | 0.88 | 0.85 | 0.85 | 0.85 | 0.82 |
| Sieve | 1.00 | 0.96 | 0.98 | 1.23 | 0.98 |
| Storage | 1.80 | 1.85 | 1.79 | 1.85 | 1.81 |
| Towers | 1.06 | 1.06 | 1.05 | 1.08 | 1.09 |

## Open questions

- Queens (1.48x manual) and List (1.15x manual) were not profiled.
- Why NBody is twice as fast in D.
- Why `VariantN!8` caused one GC collection per inner iteration in
  Storage.
- Whether the Storage slice element should become the C++ layout (8-byte
  pointer plus a length header). That layout measured 248 ms against
  C++ 283 ms.

## Files

- `data/r0-rebench.conf`, `data/r0-rebench.data`: the first ReBench run
  (section 1).
- `data/r*.tsv`: one line per executable, benchmark and invocation:
  executable name, benchmark, invocation, median ms of outer iterations
  3 to 20.
  - `r1.tsv`: before the free-order fix. `gc` and `manual` are 5a64887.
    `gc-final` and `manual-final` are the experiment with final `Vector`
    and `Set` methods (not committed).
  - `r2.tsv`: `gc`/`manual` are 28c5b5f; `gc-struct`/`manual-struct` are
    da2eb98.
  - `r3.tsv`: `gc`/`manual` are da2eb98; `gc-heap`/`manual-heap` are
    d01bc28.
  - `r4.tsv`: `gc`/`manual` are d01bc28; `gc-any`/`manual-any` are
    cb65a62 (`VariantN`).
  - `r5.tsv`: `gc`/`manual` are d01bc28; `gc-any`/`manual-any` are
    ced0b46 (`src/any.d`).
  - `cpp` is the C++ port built as above, in every file.
- `tools/compare.sh`: the timing loop.
- `tools/malloc-histogram.c`: `LD_PRELOAD` shim that counts `malloc`
  sizes and the frees that shrink the heap.
- `tools/live-blocks.c`: `LD_PRELOAD` shim that lists live heap blocks
  before the first Storage tree is built.
