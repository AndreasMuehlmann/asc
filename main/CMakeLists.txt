set(CONTROLLER_LIB_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../zig-out/lib/libasc.a")

if(EXISTS ${CONTROLLER_LIB_PATH})
  idf_component_register(SRCS "placeholder.c"
                         INCLUDE_DIRS ".")

    add_prebuilt_library(controller ${CONTROLLER_LIB_PATH})
    target_link_libraries(${COMPONENT_LIB} PRIVATE $<TARGET_OBJECTS:controller>)
else()
  idf_component_register(SRCS "main.c"
                         INCLUDE_DIRS ".")
endif()

file(GENERATE
  OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/includeDirs.txt"
  CONTENT "$<JOIN:$<TARGET_PROPERTY:${COMPONENT_LIB},INCLUDE_DIRECTORIES>,;>\n$<JOIN:${CMAKE_C_IMPLICIT_INCLUDE_DIRECTORIES},;>"
)
