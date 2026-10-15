/// A type-erased value holder that copies the design of libstdc++ `std::any`:
/// one manager function pointer and a union of a pointer and an 8-byte buffer.
module any;

import core.lifetime : emplace;
import memory : dispose, makePtr;
import std.traits : Unqual, hasElaborateCopyConstructor, hasElaborateDestructor,
    hasElaborateMove;

private enum Op {
    clone,
    destroy,
}

private union Arg {
    Any* any;
}

private union Storage {
    void* ptr;
    ubyte[size_t.sizeof] buffer;
}

private alias Manager = void function(Op, const(Any)*, Arg*);

/// The heap representation. `Box!T*` and `T*` have the same address.
private struct Box(T) {
    T value;
}

/// As libstdc++ `_Internal`: the value fits in the buffer, the alignment is
/// not greater, and a bitwise move is safe. D moves structs bitwise, which
/// is not valid for types with a copy constructor, postblit or `opPostMove`.
private enum storedInline(T) = T.sizeof <= Storage.sizeof
    && T.alignof <= Storage.alignof
    && !hasElaborateCopyConstructor!T
    && !hasElaborateMove!T;

struct Any {
    private Manager manager;
    private Storage storage;

    /// Like `std::any(value)`: stores a copy of `value` with `const` stripped.
    this(T)(T value) if (!is(Unqual!T == Any)) {
        alias U = Unqual!T;
        create!U(cast(U) value);
    }

    /// Like the `std::any` copy constructor.
    this(ref const Any other) {
        if (other.manager is null) {
            manager = null;
        } else {
            Arg arg = {any: &this};
            other.manager(Op.clone, &other, &arg);
        }
    }

    /// Like the `std::any` destructor (`reset`).
    ~this() {
        reset();
    }

    /// Like `std::any::operator=`. The value is moved bitwise, as in the
    /// libstdc++ `_Op_xfer`; `rhs` is left empty.
    ref Any opAssign(Any rhs) return {
        reset();
        manager = rhs.manager;
        storage = rhs.storage;
        rhs.manager = null;
        return this;
    }

    bool hasValue() const {
        return manager !is null;
    }

    /// Like `std::any_cast<T>(any)`. The type is checked by comparing the
    /// manager pointers. A mismatch is a programming error, so `get` halts
    /// with `assert(0)` and a message instead of throwing: the benchmarks are
    /// `nothrow`/`@nogc`-friendly and with `ManualMemory` an exception would
    /// need the GC. Under `-release` the assert is a halt without message.
    Unqual!T get(T)() const {
        alias U = Unqual!T;
        if (manager !is &manage!U)
            assert(0, "Any.get: the stored type is not " ~ U.stringof);
        return *access!U(this);
    }

    private void reset() {
        if (manager !is null) {
            manager(Op.destroy, &this, null);
            manager = null;
        }
    }

    private void create(U)(U value) {
        static if (storedInline!U) {
            emplace(cast(U*) storage.buffer.ptr, cast(U) value);
        } else {
            storage.ptr = makePtr!(Box!U)(value);
        }
        manager = &manage!U;
    }

    private static U* access(U)(ref const Any self) {
        static if (storedInline!U)
            return cast(U*) self.storage.buffer.ptr;
        else
            return cast(U*) self.storage.ptr;
    }

    private static void manage(U)(Op op, const(Any)* self, Arg* arg) {
        final switch (op) {
        case Op.clone:
            auto source = access!U(*self);
            static if (storedInline!U)
                emplace(cast(U*) arg.any.storage.buffer.ptr, *source);
            else
                arg.any.storage.ptr = makePtr!(Box!U)(*source);
            arg.any.manager = self.manager;
            break;
        case Op.destroy:
            static if (storedInline!U) {
                // A class reference is not owned: `destroy` would finalise it.
                static if (hasElaborateDestructor!U)
                    destroy!false(*access!U(*self));
            } else {
                auto box = cast(Box!U*) self.storage.ptr;
                dispose(box);
            }
            break;
        }
    }
}

static assert(Any.sizeof == 2 * size_t.sizeof);
static assert(Any.alignof == size_t.alignof);

unittest {
    auto i = Any(42);
    assert(i.hasValue);
    assert(i.get!int == 42);
    auto copy = i;
    i = Any(7);
    assert(i.get!int == 7 && copy.get!int == 42);
    assert(Any(true).get!bool);
    assert(!Any.init.hasValue);
}

unittest {
    static class Foo {
        int x;
        this(int x) {
            this.x = x;
        }
    }

    auto foo = new Foo(3);
    auto any = Any(foo);
    assert(any.get!Foo is foo);
}

unittest {
    static struct Big {
        static int copies, destroyed;
        long[3] data;
        this(this) {
            copies += 1;
        }

        ~this() {
            destroyed += 1;
        }
    }

    static assert(!storedInline!Big);
    {
        Big.copies = Big.destroyed = 0;
        auto big = Big([1, 2, 3]);
        {
            auto any = Any(big);
            auto other = any;
            assert(other.get!Big.data == [1, 2, 3]);
            assert(Big.copies >= 2);
        }
        // Every copy made is destroyed, including the temporaries of `get`.
        // Without `ManualMemory` the heap copies are left to the GC, which
        // does not run destructors, as `memory.dispose` does nothing.
        version (ManualMemory)
            assert(Big.destroyed == Big.copies);
    }
    version (ManualMemory)
        assert(Big.destroyed == Big.copies + 1);
}

unittest {
    auto any = Any(5);
    bool failed;
    try
        cast(void) any.get!long;
    catch (Error)
        failed = true;
    assert(failed);
}

unittest {
    assert(Any(cast(const int) 5).get!int == 5);
    assert(Any(5).get!(const int) == 5);
}

unittest {
    static class Owned {
        static bool finalised;
        ~this() {
            finalised = true;
        }
    }

    auto owned = new Owned;
    {
        auto any = Any(owned);
        auto copy = any;
    }
    assert(!Owned.finalised);
    assert(owned !is null);
}
