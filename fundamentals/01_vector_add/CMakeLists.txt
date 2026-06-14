add_executable(vector_add vector_add.hip)
target_link_libraries(vector_add PRIVATE hip::device rocm_common)
set_source_files_properties(vector_add.hip PROPERTIES LANGUAGE CXX)
