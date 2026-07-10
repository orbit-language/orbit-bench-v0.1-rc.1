// Servidor HTTP minimalista en C puro con Winsock.
// Single-threaded, accept/recv/send secuencial: mismo modelo de concurrencia
// que el runtime actual de Orbit (0.1-rc.1), para una comparacion justa del
// "piso" real de rendimiento sin introducir ventajas de arquitectura.
//
// Compilar (Windows, con zig cc o MSVC):
//   zig cc server.c -O2 -o server.exe -lws2_32

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#pragma comment(lib, "ws2_32.lib")

static long long fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

static void send_response(SOCKET client, int status, const char* content_type, const char* body) {
    char header[512];
    size_t body_len = strlen(body);
    int header_len = snprintf(header, sizeof(header),
        "HTTP/1.1 %d OK\r\n"
        "Content-Type: %s\r\n"
        "Content-Length: %zu\r\n"
        "Connection: close\r\n"
        "\r\n",
        status, content_type, body_len);
    send(client, header, header_len, 0);
    send(client, body, (int)body_len, 0);
}

static void handle_request(SOCKET client, const char* raw) {
    char path[256] = {0};
    const char* p = strchr(raw, ' ');
    if (!p) { send_response(client, 400, "text/plain", "Bad Request"); return; }
    p++;
    const char* pend = strchr(p, ' ');
    if (!pend) { send_response(client, 400, "text/plain", "Bad Request"); return; }
    size_t len = (size_t)(pend - p);
    if (len >= sizeof(path)) len = sizeof(path) - 1;
    memcpy(path, p, len);
    path[len] = '\0';

    if (strcmp(path, "/ping") == 0) {
        send_response(client, 200, "text/plain", "pong");
    } else if (strcmp(path, "/json") == 0) {
        send_response(client, 200, "application/json",
            "{\"message\": \"hello\", \"status\": \"ok\", \"value\": 42}");
    } else if (strcmp(path, "/compute") == 0) {
        long long result = fib(27);
        char body[64];
        snprintf(body, sizeof(body), "{\"fib\": %lld}", result);
        send_response(client, 200, "application/json", body);
    } else {
        send_response(client, 404, "text/plain", "Not Found");
    }
}

int main(void) {
    WSADATA wsa;
    WSAStartup(MAKEWORD(2, 2), &wsa);

    SOCKET server_sock = socket(AF_INET, SOCK_STREAM, 0);
    if (server_sock == INVALID_SOCKET) {
        printf("Failed to create socket\n");
        return 1;
    }

    int opt = 1;
    setsockopt(server_sock, SOL_SOCKET, SO_REUSEADDR, (const char*)&opt, sizeof(opt));

    struct sockaddr_in server_addr;
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(8081);

    if (bind(server_sock, (struct sockaddr*)&server_addr, sizeof(server_addr)) == SOCKET_ERROR) {
        printf("Bind failed\n");
        closesocket(server_sock);
        return 1;
    }

    if (listen(server_sock, 10) == SOCKET_ERROR) {
        printf("Listen failed\n");
        closesocket(server_sock);
        return 1;
    }

    printf("C raw server listening on port 8081\n");

    while (1) {
        SOCKET client_sock = accept(server_sock, NULL, NULL);
        if (client_sock == INVALID_SOCKET) continue;

        char buffer[8192];
        int received = recv(client_sock, buffer, sizeof(buffer) - 1, 0);
        if (received > 0) {
            buffer[received] = 0;
            handle_request(client_sock, buffer);
        }

        closesocket(client_sock);
    }

    WSACleanup();
    return 0;
}
