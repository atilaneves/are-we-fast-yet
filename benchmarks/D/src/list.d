module list;

import benchmark;
import memory;
import core.lifetime : move;

private struct Element {
    private Any val;
    private Element* next;

    this(Any v) {
        val = move(v);
    }

    version (ManualMemory) ~this() {
        dispose(next);
    }

    int length() {
        if (next is null)
            return 1;
        return 1 + next.length();
    }

    Any getVal() const {
        return val;
    }

    void setVal(Any v) {
        val = v;
    }

    Element* getNext() {
        return next;
    }

    void setNext(Element* e) {
        next = e;
    }
}

final class List : Benchmark {
    override Any benchmark() {
        return Any(run());
    }

    int run() {
        Element* x = makeList(15);
        Element* y = makeList(10);
        Element* z = makeList(6);

        Element* result = tail(x, y, z);
        const length = result.length();

        dispose(x);
        dispose(y);
        dispose(z);
        return length;
    }

    private Element* makeList(int length) {
        if (length == 0)
            return null;
        version (ManualMemory)
            auto e = makePtr!Element(Any(length));
        else
            auto e = new Element(Any(length));
        e.setNext(makeList(length - 1));
        return e;
    }

    private bool isShorterThan(Element* x, Element* y) {
        Element* xTail = x;
        Element* yTail = y;
        while (yTail !is null) {
            if (xTail is null)
                return true;
            xTail = xTail.getNext();
            yTail = yTail.getNext();
        }
        return false;
    }

    private Element* tail(Element* x, Element* y, Element* z) {
        if (isShorterThan(y, x)) {
            return tail(tail(x.getNext(), y, z), tail(y.getNext(), z, x),
                        tail(z.getNext(), x, y));
        }
        return z;
    }

    bool check(int result) {
        return 10 == result;
    }

    override bool verifyResult(Any result) {
        return check(result.get!int);
    }
}
