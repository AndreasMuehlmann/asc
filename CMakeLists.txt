cmake_minimum_required(VERSION 3.29)
project(MyProject VERSION 0.0.1
    DESCRIPTION "Autonomous Slot Car"
    LANGUAGES CXX)
add_executable(asc src/main.cpp)

target_include_directories(asc PUBLIC ../include)
target_link_libraries(asc zmq)
target_link_libraries(asc pigpio)
