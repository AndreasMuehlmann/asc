#include <iostream>
#include <thread>

#include "pigpio.h"

using namespace std::chrono_literals;


extern "C" {
    void button_callback(int gpio_pin, int level, unsigned int ticks) {
        std::cout << "ButtonCallback" << std::endl;    
    }
}


int main() {
    gpioInitialise();

    gpioSetMode(3, PI_OUTPUT);
    gpioWrite(3, 1);
    std::this_thread::sleep_for(1s);
    gpioWrite(3, 0);
    std::this_thread::sleep_for(1s);
    gpioWrite(3, 1);
    std::this_thread::sleep_for(1s);
    gpioWrite(3, 0);

    gpioSetMode(2, PI_INPUT);
    gpioSetISRFunc(2, FALLING_EDGE, 0, button_callback);

    gpioTerminate();
    return 0;
}
