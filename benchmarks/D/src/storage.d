module storage;

import benchmark;
import memory;
import som.random;

version (ManualMemory) {
    import core.stdc.stdlib : abort, free, malloc;
    import core.stdc.string : memset;
}

private struct ArrayTree {
    ArrayTree* children;
}

final class Storage : Benchmark {
    private int count;

    override Any benchmark() {
        return Any(run());
    }

    int run() {
        Random random;
        count = 0;
        auto result = buildTreeDepth(7, random);
        // GC build: nothing to free; the empty call would
        // still cost a guest call.
        version (ManualMemory) disposeTree(result);
        return count;
    }

    private ArrayTree* buildTreeDepth(int depth, ref Random random) {
        count += 1;
        if (depth == 1) {
            const length = random.next() % 10 + 1;
            // Not memory.d's helper: snakebite's bytecode VM
            // would not inline it.
            version (ManualMemory)
                return newTrees(length);
            else
                return (new ArrayTree[length]).ptr;
        }

        // Not memory.d's helper: snakebite's bytecode VM would not inline it.
        version (ManualMemory)
            auto arr = newTrees(4);
        else
            auto arr = (new ArrayTree[4]).ptr;
        foreach (i; 0 .. 4)
            arr[i].children = buildTreeDepth(depth - 1, random);
        return arr;
    }

    version (ManualMemory) private static ArrayTree* newTrees(size_t length) {
        // The length goes before the elements, as in the cookie of C++ new[].
        auto memory = cast(size_t*) malloc(size_t.sizeof + length * ArrayTree.sizeof);
        if (memory is null)
            abort();
        memory[0] = length;
        auto trees = cast(ArrayTree*) (memory + 1);
        memset(trees, 0, length * ArrayTree.sizeof);
        return trees;
    }

    // Last to first, as C++ delete[] destroys array elements.
    version (ManualMemory) private static void disposeTree(ArrayTree* trees) {
        if (trees is null)
            return;
        auto cookie = (cast(size_t*) trees) - 1;
        foreach_reverse (i; 0 .. cookie[0])
            disposeTree(trees[i].children);
        free(cookie);
    }

    bool check(int result) {
        return 5461 == result;
    }

    override bool verifyResult(Any result) {
        return check(result.get!int);
    }
}
