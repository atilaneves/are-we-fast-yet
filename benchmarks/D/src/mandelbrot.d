module mandelbrot;

import benchmark;
import std.stdio : writeln;

final class Mandelbrot : Runnable {
    bool innerBenchmarkLoop(int innerIterations) {
        return verifyResult(mandelbrot(innerIterations), innerIterations);
    }

    private bool verifyResult(int result, int innerIterations) {
        if (innerIterations == 500)
            return result == 191;
        if (innerIterations == 750)
            return result == 50;
        if (innerIterations == 1)
            return result == 128;

        writeln("No verification result for ", innerIterations, " found");
        writeln("Result is: ", result);
        return false;
    }

    private int mandelbrot(int size) {
        int sum = 0;
        int byteAcc = 0;
        int bitNum = 0;

        int y = 0;
        while (y < size) {
            const double ci = (2.0 * y / size) - 1.0;
            int x = 0;

            while (x < size) {
                double zrzr = 0.0;
                double zi = 0.0;
                double zizi = 0.0;
                const double cr = (2.0 * x / size) - 1.5;

                int z = 0;
                bool notDone = true;
                int escape = 0;
                while (notDone && z < 50) {
                    const double zr = zrzr - zizi + cr;
                    zi = 2.0 * zr * zi + ci;

                    zrzr = zr * zr;
                    zizi = zi * zi;

                    if (zrzr + zizi > 4.0) {
                        notDone = false;
                        escape = 1;
                    }
                    z += 1;
                }

                byteAcc = (byteAcc << 1) + escape;
                bitNum += 1;

                if (bitNum == 8) {
                    sum ^= byteAcc;
                    byteAcc = 0;
                    bitNum = 0;
                } else if (x == size - 1) {
                    byteAcc <<= (8 - bitNum);
                    sum ^= byteAcc;
                    byteAcc = 0;
                    bitNum = 0;
                }
                x += 1;
            }
            y += 1;
        }
        return sum;
    }
}
