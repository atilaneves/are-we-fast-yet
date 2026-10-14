module som.set;

import som.vector;

class Set(E) {
    private Vector!E items;

    this(size_t size = initialSize) {
        items = new Vector!E(size);
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

    Vector!T collect(T)(scope T delegate(E) fn) {
        auto coll = new Vector!T();
        forEach((e) { coll.append(fn(e)); });
        return coll;
    }

    bool contains(E obj) {
        return hasSome((e) => e == obj);
    }

    void removeAll() {
        items.removeAll();
    }
}
