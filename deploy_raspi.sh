#!/bin/bash

set -e

IP="raspberrypi.fritz.box"
USER="asc"
OUT_DIR="$(dirname "$0")/zig-out/bin"
EXE="asc"
REMOTE_DIRECTORY="asc"

scp $OUT_DIR/$EXE $USER@$IP:$REMOTE_DIRECTORY
if [ $? -eq 0 ]; then
    alacritty -e ssh -t $USER@$IP "cd $REMOTE_DIRECTORY && sudo ./$EXE; bash -l" &
fi
