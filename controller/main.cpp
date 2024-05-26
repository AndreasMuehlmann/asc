#include <iostream>
#include <thread>

#include "zmq.hpp"

using namespace std::chrono_literals;

int main () {
    zmq::context_t context (2);
    zmq::socket_t socket (context, zmq::socket_type::rep);
    socket.bind ("tcp://*:5555");

    while (true) {
        zmq::message_t request;
        socket.recv(request, zmq::recv_flags::none);
        std::cout << "Received Hello" << std::endl;
        std::this_thread::sleep_for(1s);
        zmq::message_t reply (5);
        memcpy (reply.data (), "World", 5);
        socket.send (reply, zmq::send_flags::none);
    }
    return 0;
}
