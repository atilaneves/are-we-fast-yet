module som.error;

class SomError : Exception {
    this(string message, string file = __FILE__, size_t line = __LINE__) @safe pure nothrow {
        super(message, file, line);
    }
}
