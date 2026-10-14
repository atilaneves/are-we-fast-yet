module storage;

import benchmark;
import memory;
import som.random;

private struct ArrayTree {
    ArrayTree[] children;
}

final class Storage : Benchmark!int {
    private int count;

    override int benchmark() {
        version (ManualMemory)
            scope random = new Random;
        else
            auto random = new Random;
        count = 0;
        auto result = buildTreeDepth(7, random);
        disposeTree(result);
        return count;
    }

    private ArrayTree[] buildTreeDepth(int depth, Random random) {
        count += 1;
        if (depth == 1)
            return makeArray!ArrayTree(random.next() % 10 + 1);

        auto arr = makeArray!ArrayTree(4);
        foreach (ref tree; arr)
            tree.children = buildTreeDepth(depth - 1, random);
        return arr;
    }

    private static void disposeTree(ref ArrayTree[] trees) {
        foreach (ref tree; trees)
            disposeTree(tree.children);
        disposeArray(trees);
    }

    override bool verifyResult(int result) {
        return 5461 == result;
    }
}
