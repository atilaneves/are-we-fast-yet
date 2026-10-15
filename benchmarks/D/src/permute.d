module permute;

import benchmark;
import memory;

final class Permute : Benchmark {
    private int count;
    private int[] v;

    override Any benchmark() {
        count = 0;
        v = makeArray!int(6);
        permute(6);
        disposeArray(v);
        return Any(count);
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

    override bool verifyResult(Any result) {
        return 8660 == result.get!int;
    }
}
