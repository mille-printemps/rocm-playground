#pragma once

#include <hip/hip_runtime.h>
#include <iostream>
#include <optional>
#include <source_location>
#include <string>
#include <utility>
#include <variant>

// expected / unexpected — minimal C++20 backport
//
// CUDA's toolchain targets C++20, which predates std::expected (C++23).
// This provides a small drop-in subset of the std::expected API
namespace compat {

// unexpected — wraps an error value (mirrors std::unexpected)
template <typename E>
class unexpected {
public:
    explicit unexpected(E e) : error_(std::move(e)) {}

    const E& error() const&  { return error_; }
    E&       error() &       { return error_; }
    E&&      error() &&      { return std::move(error_); }

private:
    E error_;
};

// Deduction guide so `unexpected(err)` deduces E (mirrors std::unexpected)
template <typename E>
unexpected(E) -> unexpected<E>;

// expected<T, E> — holds either a value of type T or an error of type E
template <typename T, typename E>
class expected {
public:
    // Implicit construction from a value (mirrors std::expected)
    expected(T value) : data_(std::in_place_index<0>, std::move(value)) {}

    // Construction from an error
    expected(unexpected<E> unex)
        : data_(std::in_place_index<1>, std::move(unex.error())) {}

    bool has_value() const { return data_.index() == 0; }
    explicit operator bool() const { return has_value(); }

    T&        operator*() &      { return std::get<0>(data_); }
    const T&  operator*() const& { return std::get<0>(data_); }
    T&&       operator*() &&     { return std::move(std::get<0>(data_)); }

    T&        value() &      { return std::get<0>(data_); }
    const T&  value() const& { return std::get<0>(data_); }

    const E& error() const&  { return std::get<1>(data_); }
    E&       error() &       { return std::get<1>(data_); }
    E&&      error() &&      { return std::move(std::get<1>(data_)); }

private:
    std::variant<T, E> data_;
};

// expected<void, E> — success carries no value
template <typename E>
class expected<void, E> {
public:
    expected() = default;
    expected(unexpected<E> unex) : error_(std::move(unex.error())) {}

    bool has_value() const { return !error_.has_value(); }
    explicit operator bool() const { return has_value(); }

    void value() const {}

    const E& error() const&  { return *error_; }
    E&       error() &       { return *error_; }
    E&&      error() &&      { return std::move(*error_); }

private:
    std::optional<E> error_;
};

} // namespace compat

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
using Result = compat::expected<T, HipError>;

using Void = Result<>;

// hipCheck
inline Void hipCheck(
        hipError_t err,
        std::source_location loc = std::source_location::current()) {
    if (err != hipSuccess) {
        return compat::unexpected(HipError::from(err, loc));
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
        return compat::unexpected(HipError::from(err, loc));
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
            return compat::unexpected(_result.error());         \
        }                                                       \
    } while (0)

// TRY_VAL: for expressions returning Result<T> where T is not void
// Use when the call returns a value you need:
//   auto ptr = TRY_VAL(hipAlloc<float>(N));
//   auto buf = TRY_VAL(DeviceBuffer::alloc(N));
#define TRY_VAL(name, expr)                                     \
    auto _res_##name = (expr);                                  \
    if (!_res_##name) {                                         \
        return compat::unexpected(_res_##name.error());         \
    }                                                           \
    auto name = std::move(*_res_##name)
