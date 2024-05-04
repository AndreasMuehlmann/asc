cmake_minimum_required(VERSION 3.25.1)

set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

project(asc VERSION 0.0.1
    DESCRIPTION "Autonomous Slot Car"
    LANGUAGES CXX)

add_executable(asc src/main.cpp)

target_include_directories(asc PUBLIC include)

target_link_libraries(asc c)

target_link_directories(asc PUBLIC libs)
target_link_libraries(asc zmq)
target_link_libraries(asc pigpio)
