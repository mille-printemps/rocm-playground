cmake_minimum_required(VERSION 3.21)
project(rocm-playground LANGUAGES CXX)

# ROCm / HIP setup
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find HIP — provided by ROCm installation
find_package(hip REQUIRED)

# Detect if we're on NVIDIA hardware and set HIP platform accordingly
if(DEFINED ENV{HIP_PLATFORM} AND "$ENV{HIP_PLATFORM}" STREQUAL "nvidia")
    message(STATUS "HIP platform: NVIDIA (CUDA backend)")
    add_compile_definitions(__HIP_PLATFORM_NVIDIA__)
else()
    message(STATUS "HIP platform: AMD (ROCm backend)")
endif()

# Optionally find rocPRIM and rocBLAS
find_package(rocprim QUIET)
find_package(rocblas QUIET)

if(rocprim_FOUND)
    message(STATUS "rocPRIM found")
endif()
if(rocblas_FOUND)
    message(STATUS "rocBLAS found")
endif()

add_library(rocm_common INTERFACE)
target_include_directories(rocm_common INTERFACE ${CMAKE_SOURCE_DIR}/include)
target_compile_features(rocm_common INTERFACE cxx_std_23)

# Subprojects
add_subdirectory(fundamentals)
# add_subdirectory(projects)
