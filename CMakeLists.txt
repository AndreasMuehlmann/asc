cmake_minimum_required(VERSION 3.25.1)

set(CMAKE_TOOLCHAIN_FILE "/home/andi/programming/asc/Toolchain.cmake")

project(asc VERSION 0.0.1
    DESCRIPTION "Autonomous Slot Car"
    LANGUAGES CXX)

add_executable(asc src/main.cpp)

target_include_directories(asc PUBLIC sysroot/usr/include)

target_link_directories(asc PUBLIC sysroot/usr/lib)
target_link_directories(asc PUBLIC /home/andi/programming/asc/sysroot/usr/lib/arm-linux-gnueabihf/zmq)

target_link_libraries(asc zmq)
target_link_libraries(asc pigpio)
