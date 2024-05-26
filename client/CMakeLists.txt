project(client VERSION 0.0.1
    DESCRIPTION "Client for asc"
    LANGUAGES CXX)

add_executable(client main.cpp)

target_link_libraries(client zmq)

target_include_directories(client PUBLIC "${CMAKE_SOURCE_DIR}/include")
