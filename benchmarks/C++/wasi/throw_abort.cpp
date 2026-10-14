// wasi-libc++abi is built without exception support. The benchmarks
// throw only on a failed result and never catch, so aborting matches
// the native behaviour of an uncaught exception.
#include <cstdio>
#include <cstdlib>

extern "C" void* __cxa_allocate_exception(std::size_t size) noexcept {
    return std::malloc(size);
}

extern "C" [[noreturn]] void __cxa_throw(void*, void*, void (*)(void*)) {
    std::fputs("uncaught exception: benchmark failed\n", stderr);
    std::abort();
}
