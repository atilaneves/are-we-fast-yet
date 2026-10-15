module permute;

import benchmark;
import memory;

final class Permute : Benchmark {
    private int count;
    private int[] v;

    override Any benchmark() {
        return Any(run());
    }

    int run() {
        count = 0;
        v = makeArray!int(6);
        permute(6);
        disposeArray(v);
        return count;
    }

    private void permute(int n) {
        count += 1;
        if (n != 0) {
            const n1 = n - 1;
            permute(n1);
            for (int i = n1; i >= 0; i -= 1) {
                swap(n1, i);
                permute(n1);
                swap(n1, i);
            }
        }
    }

    private void swap(int i, int j) {
        const tmp = v[i];
        v[i] = v[j];
        v[j] = tmp;
    }

    bool check(int result) {
        return 8660 == result;
    }

    override bool verifyResult(Any result) {
        return check(result.get!int);
    }
}
