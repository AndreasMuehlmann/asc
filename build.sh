#!/bin/bash


docker rm build_container
docker create -it --name build_container build_container /bin/bash

tar -cvf build.tar src/ include/ libs/ CMakeLists.txt 
docker cp build.tar build_container:/root
docker cp build_in_container.sh build_container:/root
rm build.tar

clear

docker start build_container
 
docker exec build_container chmod +x /root/build_in_container.sh
docker exec build_container /root/build_in_container.sh
docker cp build_container:/root/build/asc out

docker stop build_container
