#include <cstdlib>
#include <iostream>
#include <thread>

#include "zmq.h"

int main (void)
{
    void *context = zmq_ctx_new();
    void *requester = zmq_socket(context, ZMQ_REQ);
    zmq_connect(requester, "tcp://raspberrypi.fritz.box:5555");

    for (int count = 0; count < 10; count++) {
        char buffer[10];
        std::cout << "Sending Hello" << std::endl;
        zmq_send(requester, "Hello", 5, 0);
        zmq_recv(requester, buffer, 10, 0);
        std::cout << "Received World" << std::endl;
    }
    zmq_close(requester);
    zmq_ctx_destroy(context);
    return 0;
}
