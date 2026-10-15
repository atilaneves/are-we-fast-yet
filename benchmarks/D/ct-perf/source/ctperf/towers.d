module ctperf.towers;

import towers;

unittest {
    auto benchmark = new Towers;
    assert(benchmark.check(benchmark.run()));
}
