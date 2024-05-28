project(controller VERSION 0.0.1
    DESCRIPTION "Autonomous Slot Car"
    LANGUAGES CXX)

add_executable(controller 
    main.cpp
    commands.pb.cc

)

set(TOOLCHAIN_PATH "/home/andi/x-tools/arm-unknown-linux-gnueabihf/bin/")

set(CMAKE_C_COMPILER "${TOOLCHAIN_PATH}/arm-unknown-linux-gnueabihf-gcc")
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_PATH}/arm-unknown-linux-gnueabihf-g++")

set(CMAKE_SYSROOT "${CMAKE_SOURCE_DIR}/sysroot")
target_include_directories(controller PUBLIC "${CMAKE_SYSROOT}/usr/include/arm-linux-gnueabihf")
target_link_directories(controller PUBLIC "${CMAKE_SYSROOT}/usr/lib/arm-linux-gnueabihf")

set_target_properties(controller PROPERTIES
    LINK_FLAGS "-Wl,-rpath-link=${CMAKE_SYSROOT}/usr/lib/arm-linux-gnueabihf -Wl,-rpath=${CMAKE_SYSROOT}/usr/lib/arm-linux-gnueabihf -B${CMAKE_SYSROOT}/usr/lib/arm-linux-gnueabihf"
)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

target_link_libraries(controller pigpio)
target_link_libraries(controller zmq)
target_link_libraries(controller protobuf)

target_include_directories(controller PUBLIC "${CMAKE_SOURCE_DIR}/include")
