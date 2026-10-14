module som.dictionary;

import memory;
import som.vector;

class Dictionary(K, V) {
    protected static class Entry {
        uint hash;
        K key;
        V value;
        Entry next;

        this(uint hash, K key, V value, Entry next) {
            this.hash = hash;
            this.key = key;
            this.value = value;
            this.next = next;
        }

        bool match(uint h, K k) {
            return hash == h && key == k;
        }
    }

    enum initialCapacity = 16;

    private Entry[] buckets;
    private size_t size_;

    this(size_t capacity = initialCapacity) {
        buckets = makeArray!Entry(capacity);
    }

    version (ManualMemory) ~this() {
        removeAll();
        disposeArray(buckets);
    }

    size_t size() const {
        return size_;
    }

    bool isEmpty() const {
        return size_ == 0;
    }

    static uint hash(K key) {
        if (key is null)
            return 0;
        const h = key.customHash;
        return h ^ (h >> 16);
    }

    bool containsKey(K key) {
        const h = hash(key);
        for (Entry e = getBucket(h); e !is null; e = e.next) {
            if (e.match(h, key))
                return true;
        }
        return false;
    }

    V at(K key) {
        const h = hash(key);
        for (Entry e = getBucket(h); e !is null; e = e.next) {
            if (e.match(h, key))
                return e.value;
        }
        return V.init;
    }

    void atPut(K key, V value) {
        const h = hash(key);
        const i = getBucketIdx(h);

        Entry current = buckets[i];
        if (current is null) {
            buckets[i] = newEntry(key, value, h);
            size_ += 1;
        } else {
            insertBucketEntry(key, value, h, current);
        }

        if (size_ > buckets.length)
            resize();
    }

    void removeAll() {
        foreach (ref head; buckets) {
            for (Entry e = head; e !is null;) {
                Entry next = e.next;
                dispose(e);
                e = next;
            }
            head = null;
        }
        size_ = 0;
    }

    static if (is(V == class)) void destroyValues() {
        foreach (head; buckets) {
            for (Entry e = head; e !is null; e = e.next)
                dispose(e.value);
        }
    }

    Vector!K getKeys() {
        auto keys = make!(Vector!K)(size_);
        foreach (head; buckets) {
            for (Entry e = head; e !is null; e = e.next)
                keys.append(e.key);
        }
        return keys;
    }

    Vector!V getValues() {
        auto values = make!(Vector!V)(size_);
        foreach (head; buckets) {
            for (Entry e = head; e !is null; e = e.next)
                values.append(e.value);
        }
        return values;
    }

    protected Entry newEntry(K key, V value, uint hash) {
        return make!Entry(hash, key, value, null);
    }

    private size_t getBucketIdx(uint hash) const {
        return (buckets.length - 1) & hash;
    }

    private Entry getBucket(uint hash) {
        return buckets[getBucketIdx(hash)];
    }

    private void insertBucketEntry(K key, V value, uint hash, Entry head) {
        Entry current = head;
        while (true) {
            if (current.match(hash, key)) {
                current.value = value;
                return;
            }
            if (current.next is null) {
                size_ += 1;
                current.next = newEntry(key, value, hash);
                return;
            }
            current = current.next;
        }
    }

    private void resize() {
        auto oldStorage = buckets;
        buckets = makeArray!Entry(oldStorage.length * 2);
        transferEntries(oldStorage);
        disposeArray(oldStorage);
    }

    private void transferEntries(Entry[] oldStorage) {
        foreach (i, current; oldStorage) {
            if (current is null)
                continue;
            if (current.next is null)
                buckets[current.hash & (oldStorage.length - 1)] = current;
            else
                splitBucket(oldStorage, i, current);
        }
    }

    private void splitBucket(Entry[] oldStorage, size_t idx, Entry head) {
        Entry loHead, loTail, hiHead, hiTail;
        for (Entry current = head; current !is null; current = current.next) {
            if ((current.hash & oldStorage.length) == 0) {
                if (loTail is null)
                    loHead = current;
                else
                    loTail.next = current;
                loTail = current;
            } else {
                if (hiTail is null)
                    hiHead = current;
                else
                    hiTail.next = current;
                hiTail = current;
            }
        }

        if (loTail !is null) {
            loTail.next = null;
            buckets[idx] = loHead;
        }
        if (hiTail !is null) {
            hiTail.next = null;
            buckets[idx + oldStorage.length] = hiHead;
        }
    }
}
