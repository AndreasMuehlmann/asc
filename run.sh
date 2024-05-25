cmake --build build
$(dirname "$0")/deploy_raspi.sh
$(dirname "$0")/build/client/client 
