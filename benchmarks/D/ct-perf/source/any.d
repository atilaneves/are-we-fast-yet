// Stands in for ../src/any.d. The tests call run() and check() directly and
// never go through Any. The unittests of the real any.d cast a ubyte* to an
// int*, which the ctfe backend rejects, so the module would fail that
// backend on its own.
module any;

struct Any {
    this(T)(T value) {
    }

    T get(T)() const {
        assert(false, "the stand-in Any holds no value");
    }
}
