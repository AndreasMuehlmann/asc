#include <iostream>
#include <thread>
#include <chrono>

#include "zmq.hpp"
#include "commands.pb.h"

#include "pigpio.h"
extern "C" {
    #include "bno055.h"
}



using namespace std::chrono_literals;

#define BUS 1

void delay_msec(uint32_t msec) {
    std::this_thread::sleep_for(std::chrono::milliseconds(msec));
}

s8 i2c_read(u8 dev_id, u8 reg_addr, u8 *data, u8 len) {
    std::cout << "i2c_read" << std::endl;
    int handle = i2cOpen(BUS, dev_id, 0);
    if (handle == 1) {
        return -1;
    }

    int8_t result = i2cReadI2CBlockData(handle, reg_addr, reinterpret_cast<char*>(data), len);
    i2cClose(handle);

    return result;
}

s8 i2c_write(u8 dev_id, u8 reg_addr, u8 *data, u8 len) {
    std::cout << "i2c_write" << std::endl;
    int handle = i2cOpen(BUS, dev_id, 0);
    if (handle < 0) {
        return -1;
    }

    char buf[256];
    buf[0] = reg_addr;
    memcpy(buf + 1, data, len);

    int8_t result = i2cWriteI2CBlockData(handle, reg_addr, buf, len + 1);
    i2cClose(handle);

    return result;
}

int main() {
    if (gpioInitialise() < 0) {
        std::cerr << "pigpio initialization failed." << std::endl;
        return 1;
    }
    struct bno055_t bno055;
    bno055.bus_read = i2c_read;
    bno055.bus_write = i2c_write;
    bno055.delay_msec = delay_msec;
    bno055.dev_addr = BNO055_I2C_ADDR1;

    bno055_init(&bno055);
    struct bno055_euler_t *euler;
    std::cout << "before hrp" << std::endl;
    bno055_read_euler_hrp(euler);
    std::cout << "euler r: " << euler->r << std::endl;
    bno055_read_euler_hrp(euler);
    std::cout << "euler r: " << euler->r << std::endl;
    bno055_read_euler_hrp(euler);
    std::cout << "euler r: " << euler->r << std::endl;
    
    gpioTerminate();

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
