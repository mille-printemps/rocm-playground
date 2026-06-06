add_executable(vector_add vector_add.hip)
target_link_libraries(vector_add hip::device)
set_source_files_properties(vector_add.hip PROPERTIES LANGUAGE CXX)
