#ifndef __I2C__
#define __I2C__

#include "driver/i2c_master.h"

void i2c_bus_init(i2c_master_bus_handle_t *bus_handle);
void i2c_device_init(i2c_master_bus_handle_t *bus_handle, i2c_master_dev_handle_t *dev_handle, uint16_t address);

#endif
