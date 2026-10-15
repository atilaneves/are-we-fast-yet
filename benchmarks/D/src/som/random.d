module som.random;

struct Random {
    private int seed = 74755;

    int next() @safe pure nothrow @nogc {
        seed = ((seed * 1309) + 13849) & 65535;
        return seed;
    }
}
