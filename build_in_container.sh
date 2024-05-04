#!/bin/bash

cd /root
tar -xvf build.tar
mkdir build
cd build
cmake ..
cd ..
cmake --build build
