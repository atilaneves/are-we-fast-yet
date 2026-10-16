module ctperf.storage;

import storage;

unittest {
    auto benchmark = new Storage;
    assert(benchmark.check(benchmark.run()));
}
