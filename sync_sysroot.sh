#!/bin/bash

IP="raspberrypi.fritz.box"
USER="andi"

mkdir -p $(dirname "$0")/sysroot/usr

echo "Syncing /sysroot/usr/include"
rsync -rl $USER@$IP:/usr/include $(dirname "$0")/sysroot/usr
echo "Syncing /sysroot/usr/lib"
rsync -rl $USER@$IP:/usr/lib $(dirname "$0")/sysroot/usr
echo "Syncing /sysroot/lib"
rsync -rl $USER@$IP:/lib $(dirname "$0")/sysroot
