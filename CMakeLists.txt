cmake_minimum_required(VERSION 3.25.1)

project(asc VERSION 0.0.1
    DESCRIPTION "Autonomous Slot Car"
    LANGUAGES CXX)

set(CMAKE_BUILD_TYPE "Debug")

set(TOOLCHAIN_PATH "/home/andi/x-tools/arm-unknown-linux-gnueabihf/bin/")

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_subdirectory(controller)
