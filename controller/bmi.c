#include "bmi.h"
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "esp_rom_sys.h"
#include "driver/i2c_master.h"
#include "bmi2.h"
#include "bmi270.h"
#include "esp_log.h"
#include "common.h"

#define READ_WRITE_LEN     UINT8_C(46)
#define ACCEL          UINT8_C(0x00)
#define GYRO           UINT8_C(0x01)
#define GRAVITY_EARTH  (9.80665f)

static const char *TAG = "BMI";
static i2c_master_dev_handle_t *deviceHandle;

signed char bmiI2cRead(unsigned char reg_addr, unsigned char *reg_data, unsigned int len, void *intf) {
    int err = i2c_master_transmit_receive(*deviceHandle, &reg_addr, 1, reg_data, len, 1000);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "I2C read failed: %d", err);
        return -1;
    }
    return 0;
}

signed char bmiI2cWrite(unsigned char reg_addr, const unsigned char *reg_data, unsigned int len, void *intf) {
    if (len > 99) {
        return -2;
    }

    uint8_t writeBuffer[100];
    writeBuffer[0] = reg_addr;
    memcpy(writeBuffer + 1, reg_data, len);

    esp_err_t err = i2c_master_transmit(
            *deviceHandle,
            writeBuffer,
            len + 1,
            1000);

    if (err != ESP_OK) {
        ESP_LOGE(TAG, "I2C read failed: %d", err);
        return -1;
    }
    return 0;
}

void bmi2DelayUs(uint32_t period, void *intf) {
    esp_rom_delay_us(period);
}

void bmi2_error_codes_print_result(int8_t result)
{
    switch (result)
    {
        case BMI2_OK:
            break;

        case BMI2_W_FIFO_EMPTY:
            ESP_LOGE(TAG, "Warning [%d] : FIFO empty\r\n", result);
            break;
        case BMI2_W_PARTIAL_READ:
            ESP_LOGE(TAG, "Warning [%d] : FIFO partial read\r\n", result);
            break;
        case BMI2_E_NULL_PTR:
            ESP_LOGE(TAG, 
                "Error [%d] : Null pointer error. It occurs when the user tries to assign value (not address) to a pointer," " which has been initialized to NULL.\r\n",
                result);
            break;

        case BMI2_E_COM_FAIL:
            ESP_LOGE(TAG, 
                "Error [%d] : Communication failure error. It occurs due to read/write operation failure and also due " "to power failure during communication\r\n",
                result);
            break;

        case BMI2_E_DEV_NOT_FOUND:
            ESP_LOGE(TAG, "Error [%d] : Device not found error. It occurs when the device chip id is incorrectly read\r\n",
                   result);
            break;

        case BMI2_E_INVALID_SENSOR:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid sensor error. It occurs when there is a mismatch in the requested feature with the " "available one\r\n",
                result);
            break;

        case BMI2_E_SELF_TEST_FAIL:
            ESP_LOGE(TAG, 
                "Error [%d] : Self-test failed error. It occurs when the validation of accel self-test data is " "not satisfied\r\n",
                result);
            break;

        case BMI2_E_INVALID_INT_PIN:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid interrupt pin error. It occurs when the user tries to configure interrupt pins " "apart from INT1 and INT2\r\n",
                result);
            break;

        case BMI2_E_OUT_OF_RANGE:
            ESP_LOGE(TAG, 
                "Error [%d] : Out of range error. It occurs when the data exceeds from filtered or unfiltered data from " "fifo and also when the range exceeds the maximum range for accel and gyro while performing FOC\r\n",
                result);
            break;

        case BMI2_E_ACC_INVALID_CFG:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid Accel configuration error. It occurs when there is an error in accel configuration" " register which could be one among range, BW or filter performance in reg address 0x40\r\n",
                result);
            break;

        case BMI2_E_GYRO_INVALID_CFG:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid Gyro configuration error. It occurs when there is a error in gyro configuration" "register which could be one among range, BW or filter performance in reg address 0x42\r\n",
                result);
            break;

        case BMI2_E_ACC_GYR_INVALID_CFG:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid Accel-Gyro configuration error. It occurs when there is a error in accel and gyro" " configuration registers which could be one among range, BW or filter performance in reg address 0x40 " "and 0x42\r\n",
                result);
            break;

        case BMI2_E_CONFIG_LOAD:
            ESP_LOGE(TAG, 
                "Error [%d] : Configuration load error. It occurs when failure observed while loading the configuration " "into the sensor\r\n",
                result);
            break;

        case BMI2_E_INVALID_PAGE:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid page error. It occurs due to failure in writing the correct feature configuration " "from selected page\r\n",
                result);
            break;

        case BMI2_E_SET_APS_FAIL:
            ESP_LOGE(TAG, 
                "Error [%d] : APS failure error. It occurs due to failure in write of advance power mode configuration " "register\r\n",
                result);
            break;

        case BMI2_E_AUX_INVALID_CFG:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid AUX configuration error. It occurs when the auxiliary interface settings are not " "enabled properly\r\n",
                result);
            break;

        case BMI2_E_AUX_BUSY:
            ESP_LOGE(TAG, 
                "Error [%d] : AUX busy error. It occurs when the auxiliary interface buses are engaged while configuring" " the AUX\r\n",
                result);
            break;

        case BMI2_E_REMAP_ERROR:
            ESP_LOGE(TAG, 
                "Error [%d] : Remap error. It occurs due to failure in assigning the remap axes data for all the axes " "after change in axis position\r\n",
                result);
            break;

        case BMI2_E_GYR_USER_GAIN_UPD_FAIL:
            ESP_LOGE(TAG, 
                "Error [%d] : Gyro user gain update fail error. It occurs when the reading of user gain update status " "fails\r\n",
                result);
            break;

        case BMI2_E_SELF_TEST_NOT_DONE:
            ESP_LOGE(TAG, 
                "Error [%d] : Self-test not done error. It occurs when the self-test process is ongoing or not " "completed\r\n",
                result);
            break;

        case BMI2_E_INVALID_INPUT:
            ESP_LOGE(TAG, "Error [%d] : Invalid input error. It occurs when the sensor input validity fails\r\n", result);
            break;

        case BMI2_E_INVALID_STATUS:
            ESP_LOGE(TAG, "Error [%d] : Invalid status error. It occurs when the feature/sensor validity fails\r\n", result);
            break;

        case BMI2_E_CRT_ERROR:
            ESP_LOGE(TAG, "Error [%d] : CRT error. It occurs when the CRT test has failed\r\n", result);
            break;

        case BMI2_E_ST_ALREADY_RUNNING:
            ESP_LOGE(TAG, 
                "Error [%d] : Self-test already running error. It occurs when the self-test is already running and " "another has been initiated\r\n",
                result);
            break;

        case BMI2_E_CRT_READY_FOR_DL_FAIL_ABORT:
            ESP_LOGE(TAG, 
                "Error [%d] : CRT ready for download fail abort error. It occurs when download in CRT fails due to wrong " "address location\r\n",
                result);
            break;

        case BMI2_E_DL_ERROR:
            ESP_LOGE(TAG, 
                "Error [%d] : Download error. It occurs when write length exceeds that of the maximum burst length\r\n",
                result);
            break;

        case BMI2_E_PRECON_ERROR:
            ESP_LOGE(TAG, 
                "Error [%d] : Pre-conditional error. It occurs when precondition to start the feature was not " "completed\r\n",
                result);
            break;

        case BMI2_E_ABORT_ERROR:
            ESP_LOGE(TAG, "Error [%d] : Abort error. It occurs when the device was shaken during CRT test\r\n", result);
            break;

        case BMI2_E_WRITE_CYCLE_ONGOING:
            ESP_LOGE(TAG, 
                "Error [%d] : Write cycle ongoing error. It occurs when the write cycle is already running and another " "has been initiated\r\n",
                result);
            break;

        case BMI2_E_ST_NOT_RUNING:
            ESP_LOGE(TAG, 
                "Error [%d] : Self-test is not running error. It occurs when self-test running is disabled while it's " "running\r\n",
                result);
            break;

        case BMI2_E_DATA_RDY_INT_FAILED:
            ESP_LOGE(TAG, 
                "Error [%d] : Data ready interrupt error. It occurs when the sample count exceeds the FOC sample limit " "and data ready status is not updated\r\n",
                result);
            break;

        case BMI2_E_INVALID_FOC_POSITION:
            ESP_LOGE(TAG, 
                "Error [%d] : Invalid FOC position error. It occurs when average FOC data is obtained for the wrong" " axes\r\n",
                result);
            break;

        default:
            ESP_LOGE(TAG, "Error [%d] : Unknown error code\r\n", result);
            break;
    }
}

static int8_t set_accel_gyro_config(struct bmi2_dev *bmi)
{
    /* Status of api are returned to this variable. */
    int8_t rslt;

    /* Structure to define accelerometer and gyro configuration. */
    struct bmi2_sens_config config[2];

    /* Configure the type of feature. */
    config[ACCEL].type = BMI2_ACCEL;
    config[GYRO].type = BMI2_GYRO;

    /* Get default configurations for the type of feature selected. */
    rslt = bmi2_get_sensor_config(config, 2, bmi);
    bmi2_error_codes_print_result(rslt);

    /* Map data ready interrupt to interrupt pin. */
    rslt = bmi2_map_data_int(BMI2_DRDY_INT, BMI2_INT1, bmi);
    bmi2_error_codes_print_result(rslt);

    if (rslt == BMI2_OK)
    {
        /* NOTE: The user can change the following configuration parameters according to their requirement. */
        /* Set Output Data Rate */
        config[ACCEL].cfg.acc.odr = BMI2_ACC_ODR_200HZ;

        /* Gravity range of the sensor (+/- 2G, 4G, 8G, 16G). */
        config[ACCEL].cfg.acc.range = BMI2_ACC_RANGE_2G;

        /* The bandwidth parameter is used to configure the number of sensor samples that are averaged
         * if it is set to 2, then 2^(bandwidth parameter) samples
         * are averaged, resulting in 4 averaged samples.
         * Note1 : For more information, refer the datasheet.
         * Note2 : A higher number of averaged samples will result in a lower noise level of the signal, but
         * this has an adverse effect on the power consumed.
         */
        config[ACCEL].cfg.acc.bwp = BMI2_ACC_NORMAL_AVG4;

        /* Enable the filter performance mode where averaging of samples
         * will be done based on above set bandwidth and ODR.
         * There are two modes
         *  0 -> Ultra low power mode
         *  1 -> High performance mode(Default)
         * For more info refer datasheet.
         */
        config[ACCEL].cfg.acc.filter_perf = BMI2_PERF_OPT_MODE;

        /* The user can change the following configuration parameters according to their requirement. */
        /* Set Output Data Rate */
        config[GYRO].cfg.gyr.odr = BMI2_GYR_ODR_200HZ;

        /* Gyroscope Angular Rate Measurement Range.By default the range is 2000dps. */
        config[GYRO].cfg.gyr.range = BMI2_GYR_RANGE_2000;

        /* Gyroscope bandwidth parameters. By default the gyro bandwidth is in normal mode. */
        config[GYRO].cfg.gyr.bwp = BMI2_GYR_NORMAL_MODE;

        /* Enable/Disable the noise performance mode for precision yaw rate sensing
         * There are two modes
         *  0 -> Ultra low power mode(Default)
         *  1 -> High performance mode
         */
        config[GYRO].cfg.gyr.noise_perf = BMI2_POWER_OPT_MODE;

        /* Enable/Disable the filter performance mode where averaging of samples
         * will be done based on above set bandwidth and ODR.
         * There are two modes
         *  0 -> Ultra low power mode
         *  1 -> High performance mode(Default)
         */
        config[GYRO].cfg.gyr.filter_perf = BMI2_PERF_OPT_MODE;

        /* Set the accel and gyro configurations. */
        rslt = bmi2_set_sensor_config(config, 2, bmi);
        bmi2_error_codes_print_result(rslt);
    }

    return rslt;
}

/*!
 * @brief This function converts lsb to meter per second squared for 16 bit accelerometer at
 * range 2G, 4G, 8G or 16G.
 */
static float lsb_to_mps2(int16_t val, float g_range, uint8_t bit_width)
{
    double power = 2;

    float half_scale = (float)((pow((double)power, (double)bit_width) / 2.0f));

    return (GRAVITY_EARTH * val * g_range) / half_scale;
}

/*!
 * @brief This function converts lsb to degree per second for 16 bit gyro at
 * range 125, 250, 500, 1000 or 2000dps.
 */
static float lsb_to_dps(int16_t val, float dps, uint8_t bit_width)
{
    double power = 2;

    float half_scale = (float)((pow((double)power, (double)bit_width) / 2.0f));

    return (dps / (half_scale)) * (val);
}

struct bmi2_dev bmi;

int bmiInit(i2c_master_dev_handle_t *dHandle) {
    deviceHandle = dHandle;

    bmi.intf = BMI2_I2C_INTF;
    bmi.intf_ptr = NULL;
    bmi.read = bmiI2cRead;
    bmi.write = bmiI2cWrite;
    bmi.delay_us = bmi2DelayUs;
    bmi.read_write_len = READ_WRITE_LEN;
    bmi.config_file_ptr = NULL;

    int8_t result = bmi270_init(&bmi);
    bmi2_error_codes_print_result(result);
    if (result != BMI2_OK) {
        return -1;
    }

    result = set_accel_gyro_config(&bmi);
    bmi2_error_codes_print_result(result);
    if (result != BMI2_OK) {
        return -1;
    }

    uint8_t sensor_list[2] = { BMI2_ACCEL, BMI2_GYRO };
    result = bmi2_sensor_enable(sensor_list, 2, &bmi);
    bmi2_error_codes_print_result(result);
    if (result != BMI2_OK) {
        return -1;
    }
    return 0;
}

int bmiReadSensors(struct vec *gyro, struct vec *accel) {
    struct bmi2_sens_data sensor_data = { { 0 } };

    int8_t result = bmi2_get_sensor_data(&sensor_data, &bmi);
    bmi2_error_codes_print_result(result);

    if (result != BMI2_OK) {
        return -1;
    }
    if (!(sensor_data.status & BMI2_DRDY_ACC) || !(sensor_data.status & BMI2_DRDY_GYR)) {
        return -2;
    }

    accel->x = lsb_to_mps2(sensor_data.acc.x, (float)2, bmi.resolution);
    accel->y = lsb_to_mps2(sensor_data.acc.y, (float)2, bmi.resolution);
    accel->z = lsb_to_mps2(sensor_data.acc.z, (float)2, bmi.resolution);

    gyro->x = lsb_to_dps(sensor_data.gyr.x, (float)2000, bmi.resolution);
    gyro->y = lsb_to_dps(sensor_data.gyr.y, (float)2000, bmi.resolution);
    gyro->z = lsb_to_dps(sensor_data.gyr.z, (float)2000, bmi.resolution);

    return 0;
}

