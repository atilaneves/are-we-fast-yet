/// Allocation helpers. Without `ManualMemory` they use the GC and `dispose`
/// does nothing; with it they use malloc and free.
module memory;

version (ManualMemory) {
    import core.lifetime : emplace;
    import core.stdc.stdlib : abort, free, malloc, realloc;
    import core.stdc.string : memcpy;
}

T make(T, Args...)(auto ref Args args) if (is(T == class)) {
    version (ManualMemory) {
        enum size = __traits(classInstanceSize, T);
        auto memory = malloc(size);
        if (memory is null)
            abort();
        return emplace!T(memory[0 .. size], args);
    } else {
        return new T(args);
    }
}

void dispose(T)(ref T object) if (is(T == class) || is(T == interface)) {
    version (ManualMemory) {
        if (object is null)
            return;
        auto base = cast(Object) object;
        destroy!false(base);
        free(cast(void*) base);
        object = null;
    }
}

T[] makeArray(T)(size_t length) {
    version (ManualMemory) {
        if (length == 0)
            return null;
        auto memory = malloc(T.sizeof * length);
        if (memory is null)
            abort();
        auto array = (cast(T*) memory)[0 .. length];
        static immutable T initial = T.init;
        foreach (ref element; array)
            memcpy(&element, &initial, T.sizeof);
        return array;
    } else {
        return new T[length];
    }
}

void disposeArray(T)(ref T[] array) {
    version (ManualMemory) {
        free(array.ptr);
        array = null;
    }
}

version (ManualMemory) {
    /// Base class of objects that `ObjectTracker.releaseAll` frees.
    class TrackedObject {
        this() {
            ObjectTracker.track(this);
        }
    }

    struct ObjectTracker {
        private static TrackedObject[] objects;
        private static size_t count;

        static void track(TrackedObject tracked) {
            if (count == objects.length) {
                const newLength = objects.length == 0 ? 64 : 2 * objects.length;
                auto memory = cast(TrackedObject*) realloc(objects.ptr, newLength * TrackedObject.sizeof);
                if (memory is null)
                    abort();
                objects = memory[0 .. newLength];
            }
            objects[count] = tracked;
            count += 1;
        }

        static void releaseAll() {
            foreach (ref tracked; objects[0 .. count])
                dispose(tracked);
            free(objects.ptr);
            objects = null;
            count = 0;
        }
    }
} else {
    class TrackedObject {
    }

    struct ObjectTracker {
        static void releaseAll() {
        }
    }
}
