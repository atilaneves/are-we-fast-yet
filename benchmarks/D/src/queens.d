module queens;

import benchmark;

final class Queens : Benchmark!bool {
    private bool[] freeMaxs;
    private bool[] freeRows;
    private bool[] freeMins;
    private int[] queenRows;

    override bool benchmark() {
        bool result = true;
        foreach (i; 0 .. 10)
            result = result && queens();
        return result;
    }

    private bool queens() {
        freeRows = new bool[8];
        freeRows[] = true;
        freeMaxs = new bool[16];
        freeMaxs[] = true;
        freeMins = new bool[16];
        freeMins[] = true;
        queenRows = new int[8];
        queenRows[] = -1;
        return placeQueen(0);
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

    override bool verifyResult(bool result) {
        return result;
    }
}
