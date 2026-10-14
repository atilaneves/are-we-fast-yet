module storage;

import benchmark;
import som.random;

private struct ArrayTree {
    ArrayTree[] children;
}

final class Storage : Benchmark!int {
    private int count;

    override int benchmark() {
        auto random = new Random;
        count = 0;
        buildTreeDepth(7, random);
        return count;
    }

    private ArrayTree[] buildTreeDepth(int depth, Random random) {
        count += 1;
        if (depth == 1)
            return new ArrayTree[random.next() % 10 + 1];

        auto arr = new ArrayTree[4];
        foreach (ref tree; arr)
            tree.children = buildTreeDepth(depth - 1, random);
        return arr;
    }

    override bool verifyResult(int result) {
        return 5461 == result;
    }
}
