#include "utils.h"
#include <stdarg.h>
#include "esp_log.h"
#include "esp_log_color.h"
#include "esp_log_level.h"
#include "esp_err.h"


void espErrorCheck(int err) {
    ESP_ERROR_CHECK(err);
}

static inline const char *level_to_color(esp_log_level_t level)
{
    switch (level) {
        case ESP_LOG_ERROR:   return LOG_COLOR_E;
        case ESP_LOG_WARN:    return LOG_COLOR_W;
        case ESP_LOG_INFO:    return LOG_COLOR_I;
        case ESP_LOG_DEBUG:   return LOG_COLOR_D;
        case ESP_LOG_VERBOSE: return LOG_COLOR_V;
        default:              return "";
    }
}

static inline const char level_to_char(esp_log_level_t level) {
    switch (level) {
        case ESP_LOG_ERROR:   return 'E';
        case ESP_LOG_WARN:    return 'W';
        case ESP_LOG_INFO:    return 'I';
        case ESP_LOG_DEBUG:   return 'D';
        case ESP_LOG_VERBOSE: return 'V';
        default:              return 'I';
    }
}

void espLog(int level, const char *tag, const char *fmt, ...) {
    if (level > esp_log_level_get(tag)) {
        return;
    }

    va_list args;
    va_start(args, fmt);

    esp_log(
        (esp_log_config_t){ .data = level },
        tag,
        "%s%c (%u) %s: ",
        level_to_color(level),
        level_to_char(level),
        esp_log_timestamp(),
        tag
    );

    esp_log_writev(level, tag, fmt, args);
    esp_log_write(level, tag, "\n");

    va_end(args);
}
