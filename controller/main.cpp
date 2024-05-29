#include <iostream>
#include <thread>

#include "zmq.hpp"
#include "commands.pb.h"

using namespace std::chrono_literals;

int main () {
     
    proto::Command command;
    command.set_msg("Hello World!!!");
    std::string actual_message;
    command.SerializeToString(&actual_message);

    zmq::context_t context(2);
    zmq::socket_t socket(context, zmq::socket_type::rep);
    socket.bind("tcp://*:5555");
    
    while (true) {
        zmq::message_t request;
        socket.recv(request, zmq::recv_flags::none);
        std::string string_request = request.to_string();
        std::cout << "Received " << string_request <<std::endl;
        std::this_thread::sleep_for(1s);
        socket.send(zmq::buffer(actual_message), zmq::send_flags::none);
    }
    return 0;
}
