cmake_minimum_required(VERSION 3.21)

# Platform detection
if(DEFINED ENV{HIP_PLATFORM} AND "$ENV{HIP_PLATFORM}" STREQUAL "nvidia")
    set(HIP_PLATFORM_NVIDIA TRUE)
    project(rocm-playground LANGUAGES CXX CUDA)
else()
    set(HIP_PLATFORM_NVIDIA FALSE)
    project(rocm-playground LANGUAGES CXX)
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# CUDA settings (NVIDIA only)
if(HIP_PLATFORM_NVIDIA)
    set(CMAKE_CUDA_STANDARD 20)  # CUDA typically lags behind C++ standard support
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)
    set(CMAKE_CUDA_SEPARABLE_COMPILATION ON)
endif()

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find ROCm packages (AMD only)
if(NOT HIP_PLATFORM_NVIDIA)
    message(STATUS "Building for AMD (ROCm backend)")
    find_package(hip REQUIRED)
    find_package(rocprim QUIET)
    find_package(rocblas QUIET)
else()
    message(STATUS "Building for NVIDIA (CUDA backend)")
endif()

# Shared headers
add_library(rocm_common INTERFACE)
target_include_directories(rocm_common INTERFACE ${CMAKE_SOURCE_DIR}/include)

# Set C++ standard only (not CUDA) — CUDA targets handle it separately
target_compile_features(rocm_common INTERFACE cxx_std_20)

# Helper function
function(add_hip_executable target)
    set(sources ${ARGN})
    add_executable(${target} ${sources})

    if(HIP_PLATFORM_NVIDIA)
        # NVIDIA
        set_source_files_properties(${sources}
            PROPERTIES
                LANGUAGE CUDA
                CUDA_ARCHITECTURES "75;80;86;89")

        # Set CUDA standard on the target explicitly
        set_target_properties(${target} PROPERTIES
            CUDA_STANDARD 20
            CUDA_STANDARD_REQUIRED ON)

        target_compile_options(${target} PRIVATE
            $<$<COMPILE_LANGUAGE:CUDA>:-x=cu>)
    else()
        # AMD
        set_source_files_properties(${sources}
            PROPERTIES LANGUAGE CXX)
        target_link_libraries(${target} PRIVATE hip::device)
    endif()

    target_link_libraries(${target} PRIVATE rocm_common)
endfunction()

# Subprojects
add_subdirectory(fundamentals)
# add_subdirectory(projects)
