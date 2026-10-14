module som.identity_dictionary;

import memory;
import som.dictionary;

final class IdentityDictionary(K, V) : Dictionary!(K, V) {
    private static final class IdEntry : Entry {
        this(uint hash, K key, V value, Entry next) {
            super(hash, key, value, next);
        }

        override bool match(uint h, K k) {
            return hash == h && key is k;
        }
    }

    this(size_t capacity = initialCapacity) {
        super(capacity);
    }

    override protected Entry newEntry(K key, V value, uint hash) {
        return make!IdEntry(hash, key, value, null);
    }
}
