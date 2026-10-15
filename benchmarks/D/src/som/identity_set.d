module som.identity_set;

import som.set;

struct IdentitySet(E) {
    Set!E set;
    alias set this;

    this(size_t size) {
        set = Set!E(size);
    }

    bool contains(E obj) {
        return hasSome((e) => e is obj);
    }
}
