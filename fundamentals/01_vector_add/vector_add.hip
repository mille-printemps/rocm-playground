#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include <cassert>

// ── Macro for checking HIP errors ───────────────────────────
#define HIP_CHECK(call)                                          \
    do {                                                         \
        hipError_t err = (call);                                 \
        if (err != hipSuccess) {                                 \
            std::cerr << "HIP error at " << __FILE__            \
                      << ":" << __LINE__ << " — "               \
                      << hipGetErrorString(err) << "\n";        \
            std::exit(1);                                        \
        }                                                        \
    } while (0)

// ── The kernel — runs on GPU ─────────────────────────────────
__global__ void vectorAdd(const float* a,
                          const float* b,
                          float*       c,
                          int          n) {
    // Each thread computes its own global index
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    // Guard: there may be more threads than elements
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

int main() {
    const int N = 1 << 20;  // 1M elements
    const size_t bytes = N * sizeof(float);

    // ── Prepare input data on CPU ────────────────────────────
    std::vector<float> h_a(N, 1.0f);   // all 1s
    std::vector<float> h_b(N, 2.0f);   // all 2s
    std::vector<float> h_c(N, 0.0f);   // output

    // ── Allocate memory on GPU ───────────────────────────────
    float *d_a, *d_b, *d_c;
    HIP_CHECK(hipMalloc(&d_a, bytes));
    HIP_CHECK(hipMalloc(&d_b, bytes));
    HIP_CHECK(hipMalloc(&d_c, bytes));

    // ── Copy input from CPU to GPU ───────────────────────────
    HIP_CHECK(hipMemcpy(d_a, h_a.data(), bytes, hipMemcpyHostToDevice));
    HIP_CHECK(hipMemcpy(d_b, h_b.data(), bytes, hipMemcpyHostToDevice));

    // ── Launch kernel ────────────────────────────────────────
    int threadsPerBlock = 128;
    int blocks = (N + threadsPerBlock - 1) / threadsPerBlock;

    hipLaunchKernelGGL(vectorAdd,
                       dim3(blocks),         // grid dimensions
                       dim3(threadsPerBlock), // block dimensions
                       0,                    // shared memory bytes
                       0,                    // stream
                       d_a, d_b, d_c, N);

    HIP_CHECK(hipGetLastError());    // check kernel launch succeeded
    HIP_CHECK(hipDeviceSynchronize()); // wait for GPU to finish

    // ── Copy result back to CPU ──────────────────────────────
    HIP_CHECK(hipMemcpy(h_c.data(), d_c, bytes, hipMemcpyDeviceToHost));

    // ── Verify ───────────────────────────────────────────────
    bool correct = true;
    for (int i = 0; i < N; i++) {
        if (h_c[i] != 3.0f) {   // 1 + 2 = 3
            std::cerr << "Mismatch at index " << i
                      << ": " << h_c[i] << "\n";
            correct = false;
            break;
        }
    }

    if (correct) {
        std::cout << "✓ Vector addition correct ("
                  << N << " elements)\n";
    }

    // ── Cleanup ──────────────────────────────────────────────
    HIP_CHECK(hipFree(d_a));
    HIP_CHECK(hipFree(d_b));
    HIP_CHECK(hipFree(d_c));

    return 0;
}