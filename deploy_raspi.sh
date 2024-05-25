#!/bin/bash

IP="raspberrypi.fritz.box"
USER="andi"
OUT_DIR="$(dirname "$0")/build"
EXE="asc"
REMOTE_DIRECTORY="asc"

scp $OUT_DIR/$EXE $USER@$IP:$REMOTE_DIRECTORY
if [ $? -eq 0 ]; then
    alacritty -e ssh -t $USER@$IP "cd $REMOTE_DIRECTORY && sudo ./$EXE; bash -l" &
fi
