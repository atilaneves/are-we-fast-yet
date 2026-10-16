module ctperf.richards;

import richards;

unittest {
    auto benchmark = new Richards;
    assert(benchmark.check(benchmark.run()));
}
