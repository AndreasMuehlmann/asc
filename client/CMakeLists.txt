cmake_minimum_required(VERSION 3.25.1)

project(client VERSION 0.0.1
    DESCRIPTION "Client for asc"
    LANGUAGES CXX)

add_executable(client src/main.cpp)

target_link_libraries(client zmq)
