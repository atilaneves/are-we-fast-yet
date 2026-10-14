module list;

import benchmark;

private final class Element {
    private int val;
    private Element next;

    this(int v) {
        val = v;
    }

    int length() {
        if (next is null)
            return 1;
        return 1 + next.length();
    }

    int getVal() const {
        return val;
    }

    void setVal(int v) {
        val = v;
    }

    Element getNext() {
        return next;
    }

    void setNext(Element e) {
        next = e;
    }
}

final class List : Benchmark!int {
    override int benchmark() {
        Element result = tail(makeList(15), makeList(10), makeList(6));
        return result.length();
    }

    private Element makeList(int length) {
        if (length == 0)
            return null;
        auto e = new Element(length);
        e.setNext(makeList(length - 1));
        return e;
    }

    private bool isShorterThan(Element x, Element y) {
        Element xTail = x;
        Element yTail = y;
        while (yTail !is null) {
            if (xTail is null)
                return true;
            xTail = xTail.getNext();
            yTail = yTail.getNext();
        }
        return false;
    }

    private Element tail(Element x, Element y, Element z) {
        if (isShorterThan(y, x)) {
            return tail(tail(x.getNext(), y, z), tail(y.getNext(), z, x),
                        tail(z.getNext(), x, y));
        }
        return z;
    }

    override bool verifyResult(int result) {
        return 10 == result;
    }
}
