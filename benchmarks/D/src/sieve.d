module sieve;

import benchmark;

final class Sieve : Benchmark {
    override Any benchmark() {
        enum numFlags = 5000;
        version (ManualMemory) {
            bool[numFlags] storage;
            bool[] flags = storage[];
        } else {
            auto flags = new bool[numFlags];
        }
        flags[] = true;
        return Any(sieve(flags, 5000));
    }

    private int sieve(bool[] flags, int size) {
        int primeCount = 0;
        for (int i = 2; i <= size; i += 1) {
            if (flags[i - 1]) {
                primeCount += 1;
                int k = i + i;
                while (k <= size) {
                    flags[k - 1] = false;
                    k += i;
                }
            }
        }
        return primeCount;
    }

    override bool verifyResult(Any result) {
        return 669 == result.get!int;
    }
}
