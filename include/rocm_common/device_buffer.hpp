#pragma once

#include <hip/hip_runtime.h>
#include <cstdlib>
#include <iostream>
#include <vector>
#include "rocm_common/hip_util.hpp"

// DeviceBuffer
//
// RAII wrapper around a GPU memory allocation like Rust's owned Box<T>
// memory is freed when the buffer goes out of scope, and
// double-free is prevented by move semantics.
//
// Usage:
//   auto buf = TRY_VAL(result, DeviceBuffer<float>::alloc(N));
//   hipMemcpy(buf.ptr, h_data.data(), bytes, hipMemcpyHostToDevice);
//
template <typename T>
struct DeviceBuffer {
    T*     ptr   = nullptr;
    size_t count = 0;

    // Constructors and move semantics
    DeviceBuffer() = default;
    DeviceBuffer(T* p, size_t n) : ptr(p), count(n) {}
    // Move-only like Rust's owned types
    DeviceBuffer(DeviceBuffer&& o) noexcept
        : ptr(o.ptr), count(o.count) {
        o.ptr   = nullptr;
        o.count = 0;
    }

    // Disallow copy
    // GPU memory has a single owner
    DeviceBuffer(const DeviceBuffer&)            = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(DeviceBuffer&&)      = delete;

    // Destructor
    //
    // hipFree failure is a hardware/driver fault — unrecoverable.
    // Abort immediately rather than logging and continuing in a
    // corrupt state.
    ~DeviceBuffer() {
        if (ptr) {
            hipError_t err = hipFree(ptr);
            if (err != hipSuccess) hipFatal(err);
        }
    }

    // Factory
    //
    // Returns Result<DeviceBuffer<T>>
    // allocation errors propagate cleanly via TRY_VAL.
    static Result<DeviceBuffer<T>> alloc(size_t n) {
        TRY_VAL(p, hipAlloc<T>(n));
        return DeviceBuffer<T>{p, n};
    }

    // Utility methods

    // Size in bytes — useful for hipMemcpy calls
    size_t bytes() const { return count * sizeof(T); }

    // Copy from host vector to this buffer
    Void upload(const std::vector<T>& host) {
        return hipCheck(hipMemcpy(ptr, host.data(),
                                  bytes(),
                                  hipMemcpyHostToDevice));
    }

    // Copy from this buffer to host vector
    Void download(std::vector<T>& host) const {
        return hipCheck(hipMemcpy(host.data(), ptr,
                                  bytes(),
                                  hipMemcpyDeviceToHost));
    }
};
