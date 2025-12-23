#include <stdint.h>
#include <stdio.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "esp_log.h"

#include <esp_log.h>
#include <esp_system.h>
#include <esp_netif.h>
#include <esp_event.h>
#include <nvs_flash.h>
#include <netdb.h>

#include "server.h"
#include "lwip/sockets.h"

static const char *TAG = "server socket";

void create_listening_socket(uint16_t port, ListenerResult *listenerResult) {
    struct sockaddr_in address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if ((listenerResult->server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        listenerResult->result = SOCKET_FAILED;
        return;
    }

    int flags = fcntl(listenerResult->server_fd, F_GETFL);
    if (fcntl(listenerResult->server_fd, F_SETFL, flags | O_NONBLOCK) == -1) {
        listenerResult->result = SET_SERVER_NON_BLOCKING_FAILED;
        return;
    }

    if (bind(listenerResult->server_fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        listenerResult->result = BIND_FAILED;
        return;
    }

    if (listen(listenerResult->server_fd, 1) < 0) {
        listenerResult->result = LISTEN_FAILED;
        return;
    }

    listenerResult->result = OK;
}

static inline char* get_clients_address(struct sockaddr_storage *source_addr)
{
    static char address_str[128];
    char *res = NULL;
    if (source_addr->ss_family == PF_INET) {
        res = inet_ntoa_r(((struct sockaddr_in *)source_addr)->sin_addr, address_str, sizeof(address_str) - 1);
    }
    if (!res) {
        address_str[0] = '\0';
    }
    return address_str;
}

void wait_for_connection(int listener, ConnectionResult *connectionResult) {
    struct sockaddr_storage client_address;
    socklen_t addr_len = sizeof(client_address);
    while (true) {
        connectionResult->connection = accept(listener, (struct sockaddr *)&client_address, (socklen_t *)&addr_len);
        if (connectionResult->connection < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                vTaskDelay(10);
                continue;
            } else {
                connectionResult->result = ACCEPT_FAILED;
                return;
            }
        }
        break;
    }

    ESP_LOGI(TAG, "Connection accepted from %s", get_clients_address(&client_address));

    int flags = fcntl(connectionResult->connection, F_GETFL);
    if (fcntl(connectionResult->connection, F_SETFL, flags | O_NONBLOCK) == -1) {
        ESP_LOGE(TAG, "Couldn't set client socket of %s to non blocking.", get_clients_address(&client_address));
        connectionResult->result = SET_CLIENT_NON_BLOCKING_FAILED;
        return;
    }

    connectionResult->result = OK;
}

void non_blocking_recv(int connection, RecvResult *recvResult) {
    recvResult->bytesRead = recv(connection, recvResult->buffer, recvResult->size, 0);
    if (recvResult->bytesRead < 0) {
        if (errno == EWOULDBLOCK || errno == EAGAIN) {
            recvResult->result = WOULD_BLOCK;
        } else {
            recvResult->result = UNKNOWN;
            ESP_LOGE(TAG, "Receiving failed: %s\n", strerror(errno));
        }
    } else if (recvResult->bytesRead == 0) {
        recvResult->result = CONNECTION_CLOSED;
    } else {
        recvResult->result = OK;
    }
}

int non_blocking_send(int connection, uint8_t* buffer, size_t size) {
    size_t totalSent = 0;
    while (totalSent < size) {
        ssize_t sent = send(connection, buffer + totalSent, size - totalSent, 0);
        if (sent < 0) {
            if (errno == EWOULDBLOCK || errno == EAGAIN) {
                vTaskDelay(1);
                continue;
            }
            ESP_LOGE(TAG, "Sending failed: %s\n", strerror(errno));
            return -1;
        }
        totalSent += sent;
    }
    return OK;
}

void closeSock(int sock) {
    close(sock);
}
