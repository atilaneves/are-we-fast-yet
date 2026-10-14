module harness;

import benchmark;
import bounce;
import list;
import mandelbrot;
import nbody;
import permute;
import queens;
import richards;
import sieve;
import storage;
import towers;
import core.time : MonoTime;
import std.conv : to;
import std.stdio : stderr, writeln;

private Runnable selectBenchmark(string name) {
    switch (name) {
        case "Bounce": return new Bounce;
        case "List": return new List;
        case "Mandelbrot": return new Mandelbrot;
        case "NBody": return new NBody;
        case "Permute": return new Permute;
        case "Queens": return new Queens;
        case "Richards": return new Richards;
        case "Sieve": return new Sieve;
        case "Storage": return new Storage;
        case "Towers": return new Towers;
        default:
            stderr.writeln("Benchmark not recognized: ", name);
            return null;
    }
}

private struct Run {
    string name;
    Runnable benchmark;
    int numIterations = 1;
    int innerIterations = 1;
    long total;

    bool runBenchmark() {
        writeln("Starting ", name, " benchmark ...");
        if (!doRuns())
            return false;
        reportBenchmark();
        writeln();
        return true;
    }

    void printTotal() const {
        writeln("Total Runtime: ", total, "us");
    }

    private bool doRuns() {
        foreach (i; 0 .. numIterations) {
            if (!measure())
                return false;
        }
        return true;
    }

    private bool measure() {
        const start = MonoTime.currTime;
        if (!benchmark.innerBenchmarkLoop(innerIterations)) {
            writeln("Benchmark failed with incorrect result");
            return false;
        }
        const runTime = (MonoTime.currTime - start).total!"usecs";

        writeln(name, ": iterations=1 runtime: ", runTime, "us");
        total += runTime;
        return true;
    }

    private void reportBenchmark() const {
        writeln(name, ": iterations=", numIterations, " average: ",
                total / numIterations, "us total: ", total, "us");
    }
}

private void printUsage() {
    writeln("./harness benchmark [num-iterations [inner-iter]]");
    writeln();
    writeln("  benchmark      - benchmark class name");
    writeln("  num-iterations - number of times to execute benchmark, default: 1");
    writeln("  inner-iter     - number of times the benchmark is executed in an inner loop,");
    writeln("                   which is measured in total, default: 1");
}

int main(string[] args) {
    if (args.length < 2) {
        printUsage();
        return 1;
    }

    auto run = Run(args[1], selectBenchmark(args[1]));
    if (run.benchmark is null)
        return 1;
    if (args.length > 2) {
        run.numIterations = args[2].to!int;
        if (args.length > 3)
            run.innerIterations = args[3].to!int;
    }

    if (!run.runBenchmark())
        return 1;
    run.printTotal();
    return 0;
}
