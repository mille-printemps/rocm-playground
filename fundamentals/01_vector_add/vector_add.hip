#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include "rocm_common/hip_util.hpp"
#include "rocm_common/device_buffer.hpp"

// Kernel
__global__ void vectorAdd(const float* a,
                          const float* b,
                          float*       c,
                          int          n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

// Core logic
Void run() {
    const int N = 1 << 20;

    std::vector<float> h_a(N, 1.0f);
    std::vector<float> h_b(N, 2.0f);
    std::vector<float> h_c(N, 0.0f);

    // Allocate GPU buffers
    TRY_VAL(buf_a, DeviceBuffer<float>::alloc(N));
    TRY_VAL(buf_b, DeviceBuffer<float>::alloc(N));
    TRY_VAL(buf_c, DeviceBuffer<float>::alloc(N));

    // Upload input data
    TRY_VOID(buf_a.upload(h_a));
    TRY_VOID(buf_b.upload(h_b));

    // Launch kernel
    int threadsPerBlock = 256;
    int blocks = (N + threadsPerBlock - 1) / threadsPerBlock;

    hipLaunchKernelGGL(vectorAdd,
                       dim3(blocks),
                       dim3(threadsPerBlock),
                       0, 0,
                       buf_a.ptr, buf_b.ptr, buf_c.ptr, N);

    TRY_VOID(hipCheck(hipGetLastError()));
    TRY_VOID(hipCheck(hipDeviceSynchronize()));

    // Download result
    TRY_VOID(buf_c.download(h_c));

    // Verify
    for (int i = 0; i < N; i++) {
        if (h_c[i] != 3.0f) {
            return std::unexpected(HipError{
                .code    = hipErrorUnknown,
                .message = "Mismatch at index "
                         + std::to_string(i)
                         + ": got " + std::to_string(h_c[i])
            });
        }
    }

    std::cout << "✓ Vector addition correct (" << N << " elements)\n";
    return {};
}

int main() {
    auto result = run();
    if (!result) {
        std::cerr << "Error: " << result.error().message << "\n";
        return 1;
    }
    return 0;
}
