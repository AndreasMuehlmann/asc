#include <iostream>
#include <unistd.h>
#include <assert.h>

#include <zmq.h>
#include <pigpio.h>
/*
extern "C"
void button_callback(int gpio_pin, int level, unsigned int ticks) {
    std::cout << "ButtonCallback" << std::endl;    
}
*/

int main() {
    void *context = zmq_ctx_new();
    std::cout << "Hello World!" << std::endl;
    /*
    void *responder = zmq_socket(context, ZMQ_REP);
    int rc = zmq_bind (responder, "tcp://*:5555");
    assert(rc == 0);

    while (1) {
        char buffer[10];
        zmq_recv(responder, buffer, 10, 0);
        std::cout << ("Received Hello\n") << std::endl;
        sleep(1);
        zmq_send(responder, "World", 5, 0);
    }
    */
    gpioInitialise();
    gpioSetMode(3, PI_OUTPUT);
    gpioWrite(3, 1);
    sleep(1);
    gpioWrite(3, 0);
    sleep(1);
    gpioWrite(3, 1);
    sleep(1);
    gpioWrite(3, 0);

    // gpioSetMode(2, PI_INPUT);
    // gpioSetISRFunc(2, FALLING_EDGE, 0, button_callback);
    gpioTerminate();
    return 0;
}
