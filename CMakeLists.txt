cmake_minimum_required(VERSION 3.21)
project(rocm-playground LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Platform detection
if(DEFINED ENV{HIP_PLATFORM} AND "$ENV{HIP_PLATFORM}" STREQUAL "nvidia")
    set(HIP_PLATFORM_NVIDIA TRUE)
    message(STATUS "Building for NVIDIA (CUDA backend)")
else()
    set(HIP_PLATFORM_NVIDIA FALSE)
    message(STATUS "Building for AMD (ROCm backend)")
    find_package(hip REQUIRED)
    find_package(rocprim QUIET)
    find_package(rocblas QUIET)
endif()

# Shared headers
add_library(rocm_common INTERFACE)
target_include_directories(rocm_common INTERFACE ${CMAKE_SOURCE_DIR}/include)
target_compile_features(rocm_common INTERFACE cxx_std_23)

# Helper function
function(add_hip_executable target)
    set(sources ${ARGN})
    add_executable(${target} ${sources})

    if(HIP_PLATFORM_NVIDIA)
        set_source_files_properties(${sources}
            PROPERTIES
                LANGUAGE CUDA
                COMPILE_OPTIONS "-x;cu")
    else()
        set_source_files_properties(${sources}
            PROPERTIES LANGUAGE CXX)
        target_link_libraries(${target} PRIVATE hip::device)
    endif()

    target_link_libraries(${target} PRIVATE rocm_common)
endfunction()

# Subprojects
add_subdirectory(fundamentals)
# add_subdirectory(projects)
