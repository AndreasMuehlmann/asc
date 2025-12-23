#ifndef __SERVER__
#define __SERVER__

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#define OK 0
#define SOCKET_FAILED -1
#define BIND_FAILED -2
#define SET_SERVER_NON_BLOCKING_FAILED -3
#define LISTEN_FAILED -4
#define ACCEPT_FAILED -5 
#define SET_CLIENT_NON_BLOCKING_FAILED -6 
#define WOULD_BLOCK -7 
#define CONNECTION_CLOSED -8 
#define UNKNOWN -9 

typedef struct {
    int server_fd;
    int result;
} ListenerResult;

typedef struct {
    int connection;
    int result;
} ConnectionResult;

typedef struct {
    uint8_t *buffer;
    size_t size;
    int result;
    int bytesRead;
} RecvResult;

typedef struct {
    uint8_t *buffer;
    size_t size;
    int result;
    ssize_t bytesRead;
} SendResult;

void create_listening_socket(uint16_t port, ListenerResult *listenerResult);
void wait_for_connection(int listener, ConnectionResult *connectionResult);
void closeSock(int sock);

void non_blocking_recv(int connection, RecvResult *recvResult);
int non_blocking_send(int connection, uint8_t* buffer, size_t size);

#endif
