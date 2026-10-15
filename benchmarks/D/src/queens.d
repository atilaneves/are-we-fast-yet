module queens;

import benchmark;
import memory;

final class Queens : Benchmark {
    private bool[] freeMaxs;
    private bool[] freeRows;
    private bool[] freeMins;
    private int[] queenRows;

    override Any benchmark() {
        bool result = true;
        foreach (i; 0 .. 10)
            result = result && queens();
        return Any(result);
    }

    private bool queens() {
        freeRows = makeArray!bool(8);
        freeRows[] = true;
        freeMaxs = makeArray!bool(16);
        freeMaxs[] = true;
        freeMins = makeArray!bool(16);
        freeMins[] = true;
        queenRows = makeArray!int(8);
        queenRows[] = -1;

        const result = placeQueen(0);

        disposeArray(freeRows);
        disposeArray(freeMaxs);
        disposeArray(freeMins);
        disposeArray(queenRows);
        return result;
    }

    private bool placeQueen(int c) {
        foreach (r; 0 .. 8) {
            if (getRowColumn(r, c)) {
                queenRows[r] = c;
                setRowColumn(r, c, false);

                if (c == 7)
                    return true;

                if (placeQueen(c + 1))
                    return true;
                setRowColumn(r, c, true);
            }
        }
        return false;
    }

    private bool getRowColumn(int r, int c) {
        return freeRows[r] && freeMaxs[c + r] && freeMins[c - r + 7];
    }

    private void setRowColumn(int r, int c, bool v) {
        freeRows[r] = v;
        freeMaxs[c + r] = v;
        freeMins[c - r + 7] = v;
    }

    override bool verifyResult(Any result) {
        return result.get!bool;
    }
}
