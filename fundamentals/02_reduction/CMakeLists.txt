add_executable(reduction reduction.hip)
target_link_libraries(reduction PRIVATE hip::device rocm_common)
set_source_files_properties(reduction.hip PROPERTIES LANGUAGE CXX)
