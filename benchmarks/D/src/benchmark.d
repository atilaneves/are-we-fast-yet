module benchmark;

interface Runnable {
    bool innerBenchmarkLoop(int innerIterations);
}

abstract class Benchmark(R) : Runnable {
    abstract R benchmark();
    abstract bool verifyResult(R result);

    bool innerBenchmarkLoop(int innerIterations) {
        foreach (i; 0 .. innerIterations) {
            if (!verifyResult(benchmark()))
                return false;
        }
        return true;
    }
}
