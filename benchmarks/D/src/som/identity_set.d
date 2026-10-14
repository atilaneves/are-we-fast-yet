module som.identity_set;

import som.set;
import som.vector;

final class IdentitySet(E) : Set!E {
    this(size_t size = initialSize) {
        super(size);
    }

    override bool contains(E obj) {
        return hasSome((e) => e is obj);
    }
}
