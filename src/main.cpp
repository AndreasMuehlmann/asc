#include <iostream>
#include <unistd.h>

// #include <zmq.h>
#include <pigpio.h>

extern "C"
void button_callback(int gpio_pin, int level, unsigned int ticks) {
    std::cout << "ButtonCallback" << std::endl;    
}

int main() {
    std::cout << "Hello World!" << std::endl;    
    gpioInitialise();
    gpioSetMode(3, PI_OUTPUT);
    gpioWrite(3, 1);
    sleep(1);
    gpioWrite(3, 0);
    sleep(1);
    gpioWrite(3, 1);
    sleep(1);
    gpioWrite(3, 0);

    gpioSetMode(2, PI_INPUT);
    gpioSetISRFunc(2, FALLING_EDGE, 0, button_callback);
    gpioTerminate();
}
