#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include <numeric>
#include <cmath>
#include "rocm_common/hip_util.hpp"
#include "rocm_common/device_buffer.hpp"

// Level 1 kernel: each block reduces its chunk
__global__ void blockReduce(const float* input,
                            float*       partialSums,
                            int          n) {
    extern __shared__ float sdata[];

    int tid    = threadIdx.x;
    int global = blockIdx.x * blockDim.x + threadIdx.x;

    sdata[tid] = (global < n) ? input[global] : 0.0f;
    __syncthreads();

    for (int stride = blockDim.x / 2; stride > 0; stride >>= 1) {
        if (tid < stride) {
            sdata[tid] += sdata[tid + stride];
        }
        __syncthreads();
    }

    if (tid == 0) {
        partialSums[blockIdx.x] = sdata[0];
    }
}

// CPU reference
float cpuSum(const std::vector<float>& v) {
    return std::accumulate(v.begin(), v.end(), 0.0f);
}

// Core logic
Void run() {
    const int N       = 1 << 20;
    const int THREADS = 256;
    const int BLOCKS  = (N + THREADS - 1) / THREADS;

    // Prepare host data
    std::vector<float> h_input(N);
    for (int i = 0; i < N; i++) h_input[i] = 1.0f;

    float expected = cpuSum(h_input);
    std::cout << "CPU sum: " << expected << "\n";

    // Allocate GPU buffers
    TRY_VAL(buf_input,   DeviceBuffer<float>::alloc(N));
    TRY_VAL(buf_partial, DeviceBuffer<float>::alloc(BLOCKS));
    TRY_VAL(buf_final,   DeviceBuffer<float>::alloc(1));

    // Upload input data
    TRY_VOID(buf_input.upload(h_input));

    // Level 1: each block reduces its chunk
    hipLaunchKernelGGL(blockReduce,
                       dim3(BLOCKS),
                       dim3(THREADS),
                       THREADS * sizeof(float),
                       0,
                       buf_input.ptr, buf_partial.ptr, N);

    TRY_VOID(hipCheck(hipGetLastError()));
    TRY_VOID(hipCheck(hipDeviceSynchronize()));

    // Level 2: reduce the partial sums
    hipLaunchKernelGGL(blockReduce,
                       dim3(1),
                       dim3(THREADS),
                       THREADS * sizeof(float),
                       0,
                       buf_partial.ptr, buf_final.ptr, BLOCKS);

    TRY_VOID(hipCheck(hipGetLastError()));
    TRY_VOID(hipCheck(hipDeviceSynchronize()));

    // Download result
    std::vector<float> h_result(1);
    TRY_VOID(buf_final.download(h_result));
    float gpu_sum = h_result[0];

    std::cout << "GPU sum: " << gpu_sum << "\n";

    // Verify
    float diff = std::fabs(gpu_sum - expected);
    float tol  = expected * 1e-5f;

    if (diff > tol) {
        return std::unexpected(HipError{
            .code    = hipErrorUnknown,
            .message = "Result mismatch: GPU=" + std::to_string(gpu_sum)
                     + " CPU="                 + std::to_string(expected)
                     + " diff="                + std::to_string(diff)
        });
    }

    std::cout << "✓ Reduction correct (diff=" << diff << ")\n";
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
