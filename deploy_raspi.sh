#!/bin/bash

IP="raspberrypi.fritz.box"
USER="andi"
FILE_TO_COPY="zig-out/bin/asc"
REMOTE_DIRECTORY="asc"

scp $FILE_TO_COPY $USER@$IP:$REMOTE_DIRECTORY
if [ $? -eq 0 ]; then
    alacritty -e ssh -t $USER@$IP "cd $REMOTE_DIRECTORY && sudo ./$(basename ${FILE_TO_COPY}); bash -l" &
fi
