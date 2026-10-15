module ctperf.json;

import json;

unittest {
    auto benchmark = new Json;
    assert(benchmark.check(benchmark.run()));
}
