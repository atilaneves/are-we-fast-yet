module ctperf.sieve;

import sieve;

unittest {
    auto benchmark = new Sieve;
    assert(benchmark.check(benchmark.run()));
}
