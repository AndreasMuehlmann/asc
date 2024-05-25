#include <cstdlib>
#include <iostream>
#include <thread>

#include "zmq.h"

using namespace std::chrono_literals;


int main (void)
{
    void *context = zmq_ctx_new();
    void *responder = zmq_socket(context, ZMQ_REP);
    int rc = zmq_bind(responder, "tcp://*:5555");
    if (rc == 1) {
        std::cout << "binding to port not possible" << std::endl;
        std::exit(1);
    }

    while (true) {
        char buffer[10];
        zmq_recv(responder, buffer, 10, 0);
        std::cout << "Received Hello" << std::endl;
        std::this_thread::sleep_for(1s);
        zmq_send (responder, "World", 5, 0);
    }
    return 0;
}
