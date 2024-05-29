$(dirname "$0")/helper_programs/protoc -Iproto --cpp_out=controller proto/*.proto
$(dirname "$0")/helper_programs/protoc -Iproto  --python_out=client proto/*.proto
cmake --build build
