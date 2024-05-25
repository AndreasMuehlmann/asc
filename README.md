# ASC - Autonomous Slot Car

An autonomous slot-car, written in zig, running on a raspberry pi

## Build Command
arm-unknown-linux-gnueabihf-g++ src/main.cpp -o build/asc -lpigpio -lzmq -Isysroot/usr/include/arm-linux-gnueabihf/ -Lsysroot/usr/lib/arm-linux-gnueabihf -Bsysroot/usr/lib/arm-linux-gnueabihf --sysroot=sysroot -Wl,-rpath-link=sysroot/usr/lib/arm-linux-gnueabihf -Wl,-rpath=sysroot/usr/lib/arm-linux-gnueabihf
