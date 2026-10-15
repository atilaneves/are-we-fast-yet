module storage;

import benchmark;
import memory;
import som.random;

private struct ArrayTree {
    ArrayTree[] children;
}

final class Storage : Benchmark {
    private int count;

    override Any benchmark() {
        Random random;
        count = 0;
        auto result = buildTreeDepth(7, random);
        disposeTree(result);
        return Any(count);
    }

    private ArrayTree[] buildTreeDepth(int depth, ref Random random) {
        count += 1;
        if (depth == 1)
            return makeArray!ArrayTree(random.next() % 10 + 1);

        auto arr = makeArray!ArrayTree(4);
        foreach (ref tree; arr)
            tree.children = buildTreeDepth(depth - 1, random);
        return arr;
    }

    // Last to first, as C++ delete[] destroys array elements.
    private static void disposeTree(ref ArrayTree[] trees) {
        foreach_reverse (ref tree; trees)
            disposeTree(tree.children);
        disposeArray(trees);
    }

    override bool verifyResult(Any result) {
        return 5461 == result.get!int;
    }
}
