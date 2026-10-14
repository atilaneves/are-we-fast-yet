module som.vector;

import memory;

enum initialSize = 10;

class Vector(E) {
    private E[] storage;
    private size_t firstIdx;
    private size_t lastIdx;

    static Vector!E with_(E elem) {
        auto v = make!(Vector!E)(1);
        v.append(elem);
        return v;
    }

    this(size_t size = 0) {
        storage = makeArray!E(size);
    }

    version (ManualMemory) ~this() {
        disposeArray(storage);
    }

    E at(size_t idx) {
        if (idx >= storage.length)
            return E.init;
        return storage[idx];
    }

    void atPut(size_t idx, E val) {
        if (storage.length == 0) {
            storage = makeArray!E(idx + 1 > initialSize ? idx + 1 : initialSize);
        } else if (idx >= storage.length) {
            size_t newLength = storage.length;
            while (newLength <= idx)
                newLength *= 2;
            grow(newLength);
        }
        storage[idx] = val;
        if (lastIdx < idx + 1)
            lastIdx = idx + 1;
    }

    void append(E elem) {
        if (storage.length == 0)
            storage = makeArray!E(initialSize);
        else if (lastIdx >= storage.length)
            grow(2 * storage.length);
        storage[lastIdx] = elem;
        lastIdx += 1;
    }

    bool isEmpty() const {
        return lastIdx == firstIdx;
    }

    void forEach(scope void delegate(E) fn) {
        for (size_t i = firstIdx; i < lastIdx; i += 1)
            fn(storage[i]);
    }

    bool hasSome(scope bool delegate(E) fn) {
        for (size_t i = firstIdx; i < lastIdx; i += 1) {
            if (fn(storage[i]))
                return true;
        }
        return false;
    }

    E getOne(scope bool delegate(E) fn) {
        for (size_t i = firstIdx; i < lastIdx; i += 1) {
            E e = storage[i];
            if (fn(e))
                return e;
        }
        return E.init;
    }

    E first() {
        if (isEmpty)
            return E.init;
        return storage[firstIdx];
    }

    E removeFirst() {
        if (isEmpty)
            return E.init;
        firstIdx += 1;
        return storage[firstIdx - 1];
    }

    bool remove(E obj) {
        if (storage.length == 0 || isEmpty)
            return false;

        auto newArray = makeArray!E(capacity);
        size_t newLast = 0;
        bool found = false;

        forEach((it) {
            if (it is obj) {
                found = true;
            } else {
                newArray[newLast] = it;
                newLast += 1;
            }
        });

        disposeArray(storage);
        storage = newArray;
        lastIdx = newLast;
        firstIdx = 0;
        return found;
    }

    void removeAll() {
        firstIdx = 0;
        lastIdx = 0;
        const length = storage.length;
        disposeArray(storage);
        storage = makeArray!E(length);
    }

    static if (is(E == class)) void destroyValues() {
        for (size_t i = firstIdx; i < lastIdx; i += 1)
            dispose(storage[i]);
    }

    size_t size() const {
        return lastIdx - firstIdx;
    }

    size_t capacity() const {
        return storage.length;
    }

    void sort(scope int delegate(E, E) c) {
        if (size > 0)
            sortRange(firstIdx, lastIdx - 1, c);
    }

    private void grow(size_t newLength) {
        auto newStorage = makeArray!E(newLength);
        newStorage[0 .. storage.length] = storage[];
        disposeArray(storage);
        storage = newStorage;
    }

    private void sortRange(size_t i, size_t j, scope int delegate(E, E) c) {
        const n = j + 1 - i;
        if (n <= 1)
            return;

        E di = storage[i];
        E dj = storage[j];

        if (c(di, dj) > 0) {
            swap(i, j);
            E tt = di;
            di = dj;
            dj = tt;
        }

        if (n > 2) {
            const ij = (i + j) / 2;
            E dij = storage[ij];

            if (c(di, dij) <= 0) {
                if (c(dij, dj) > 0) {
                    swap(j, ij);
                    dij = dj;
                }
            } else {
                swap(i, ij);
                dij = di;
            }

            if (n > 3) {
                size_t k = i;
                size_t l = j - 1;

                while (true) {
                    while (k <= l && c(dij, storage[l]) <= 0)
                        l -= 1;

                    k += 1;
                    while (k <= l && c(storage[k], dij) <= 0)
                        k += 1;

                    if (k > l)
                        break;
                    swap(k, l);
                }

                sortRange(i, l, c);
                sortRange(k, j, c);
            }
        }
    }

    private void swap(size_t i, size_t j) {
        auto tmp = storage[i];
        storage[i] = storage[j];
        storage[j] = tmp;
    }
}
