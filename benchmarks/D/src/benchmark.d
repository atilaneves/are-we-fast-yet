module benchmark;

public import any : Any;

interface Runnable {
    bool innerBenchmarkLoop(int innerIterations);
}

abstract class Benchmark : Runnable {
    abstract Any benchmark();
    abstract bool verifyResult(Any result);

    bool innerBenchmarkLoop(int innerIterations) {
        foreach (i; 0 .. innerIterations) {
            if (!verifyResult(benchmark()))
                return false;
        }
        return true;
    }
}
