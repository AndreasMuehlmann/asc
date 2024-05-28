#!/bin/bash

mkdir -p $(dirname "$0")/sysroot/usr

echo "Syncing /sysroot/usr/include"
rsync -rl andi@raspberrypi.fritz.box:/usr/include $(dirname "$0")/sysroot/usr
echo "Syncing /sysroot/usr/lib"
rsync -rl andi@raspberrypi.fritz.box:/usr/lib $(dirname "$0")/sysroot/usr
echo "Syncing /sysroot/lib"
rsync -rl andi@raspberrypi.fritz.box:/lib $(dirname "$0")/sysroot
