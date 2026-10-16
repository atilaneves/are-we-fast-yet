module ctperf.permute;

import permute;

unittest {
    auto benchmark = new Permute;
    assert(benchmark.check(benchmark.run()));
}
