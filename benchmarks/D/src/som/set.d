module som.set;

import memory;
import som.vector;

struct Set(E) {
    private Vector!E items;

    this(size_t size) {
        items = Vector!E(size);
    }

    size_t size() const {
        return items.size;
    }

    void forEach(scope void delegate(E) fn) {
        items.forEach(fn);
    }

    bool hasSome(scope bool delegate(E) fn) {
        return items.hasSome(fn);
    }

    E getOne(scope bool delegate(E) fn) {
        return items.getOne(fn);
    }

    void add(E obj) {
        if (!contains(obj))
            items.append(obj);
    }

    Vector!T* collect(T)(scope T delegate(E) fn) {
        auto coll = makePtr!(Vector!T);
        forEach((e) { coll.append(fn(e)); });
        return coll;
    }

    bool contains(E obj) {
        static if (is(E == class))
            return hasSome((e) => e.equal(obj));
        else
            return hasSome((e) => e == obj);
    }

    void removeAll() {
        items.removeAll();
    }
}
