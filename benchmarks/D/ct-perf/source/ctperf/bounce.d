module ctperf.bounce;

import bounce;

unittest {
    auto benchmark = new Bounce;
    assert(benchmark.check(benchmark.run()));
}
