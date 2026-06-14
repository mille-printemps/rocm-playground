#pragma once

#include <hip/hip_runtime.h>
#include <expected>
#include <string>
#include <source_location>

// Error type
struct HipError {
    hipError_t  code;
    std::string message;

    static HipError from(
            hipError_t err,
            std::source_location loc = std::source_location::current()) {
        return HipError{
            .code    = err,
            .message = std::string(loc.file_name())
                     + ":" + std::to_string(loc.line())
                     + " — " + hipGetErrorString(err)
        };
    }
};

// Result types
template <typename T = void>
using Result = std::expected<T, HipError>;

using Void = Result<>;

// hipCheck
inline Void hipCheck(
        hipError_t err,
        std::source_location loc = std::source_location::current()) {
    if (err != hipSuccess) {
        return std::unexpected(HipError::from(err, loc));
    }
    return {};
}

// hipAlloc
template <typename T>
Result<T*> hipAlloc(
        size_t count,
        std::source_location loc = std::source_location::current()) {
    T* ptr = nullptr;
    hipError_t err = hipMalloc(&ptr, count * sizeof(T));
    if (err != hipSuccess) {
        return std::unexpected(HipError::from(err, loc));
    }
    return ptr;
}

// Fatal error
//
// Use in destructors and other noexcept contexts where
// a HIP error indicates hardware trouble and cannot be propagated.
[[noreturn]] inline void hipFatal(
        hipError_t err,
        std::source_location loc = std::source_location::current()) {
    std::cerr << "Fatal HIP error at "
              << loc.file_name() << ":" << loc.line()
              << " — " << hipGetErrorString(err) << "\n"
              << "Aborting.\n";
    std::abort();
}

// TRY macros — no statement expressions

// TRY_VOID: for expressions returning Void (Result<void>)
// Use when the call returns no value on success:
//   TRY_VOID(hipCheck(hipDeviceSynchronize()));
//   TRY_VOID(hipCheck(hipMemcpy(...)));
#define TRY_VOID(expr)                                          \
    do {                                                        \
        auto _result = (expr);                                  \
        if (!_result) {                                         \
            return std::unexpected(_result.error());            \
        }                                                       \
    } while (0)

// TRY_VAL: for expressions returning Result<T> where T is not void
// Use when the call returns a value you need:
//   auto ptr = TRY_VAL(hipAlloc<float>(N));
//   auto buf = TRY_VAL(DeviceBuffer::alloc(N));
#define TRY_VAL(name, expr)                                     \
    auto _res_##name = (expr);                                  \
    if (!_res_##name) {                                         \
        return std::unexpected(_res_##name.error());            \
    }                                                           \
    auto name = std::move(*_res_##name)
