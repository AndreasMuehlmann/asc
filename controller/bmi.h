#ifndef __BMI__
#define __BMI__

#include "driver/i2c_master.h"

struct vec {
    float x;
    float y;
    float z;
};

int bmiInit(i2c_master_dev_handle_t *dHandle);
int bmiReadSensors(struct vec *gyro, struct vec *accel);

#endif
