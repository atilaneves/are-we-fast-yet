module ctperf.queens;

import queens;

unittest {
    auto benchmark = new Queens;
    assert(benchmark.check(benchmark.run()));
}
