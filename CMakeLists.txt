cmake_minimum_required(VERSION 3.21)
project(rocm-playground LANGUAGES CXX)

# ROCm / HIP setup
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find HIP — provided by ROCm installation
find_package(hip REQUIRED)

# Optionally find rocPRIM and rocBLAS
find_package(rocprim QUIET)
find_package(rocblas QUIET)

if(rocprim_FOUND)
    message(STATUS "rocPRIM found")
endif()
if(rocblas_FOUND)
    message(STATUS "rocBLAS found")
endif()

# Subprojects
add_subdirectory(fundamentals)
# add_subdirectory(projects)
