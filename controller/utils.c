#include "utils.h"
#include "esp_err.h"


void espErrorCheck(int err) {
    ESP_ERROR_CHECK(err);
}
