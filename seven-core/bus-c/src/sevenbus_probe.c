#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

static const char *state_for_bool(int ok) {
    return ok ? "OK" : "MISS";
}

static void print_json(void) {
    int unix_pair[2] = {-1, -1};
    int stream_pair[2] = {-1, -1};
    int seqpacket_pair[2] = {-1, -1};

    int unix_ok = socketpair(AF_UNIX, SOCK_DGRAM, 0, unix_pair) == 0;
    int stream_ok = socketpair(AF_UNIX, SOCK_STREAM, 0, stream_pair) == 0;
    int seqpacket_ok = socketpair(AF_UNIX, SOCK_SEQPACKET, 0, seqpacket_pair) == 0;

    if (unix_ok) {
        close(unix_pair[0]);
        close(unix_pair[1]);
    }
    if (stream_ok) {
        close(stream_pair[0]);
        close(stream_pair[1]);
    }
    if (seqpacket_ok) {
        close(seqpacket_pair[0]);
        close(seqpacket_pair[1]);
    }

    printf("{");
    printf("\"schema\":\"sevenos.bus-c.v1\",");
    printf("\"language\":\"c\",");
    printf("\"role\":\"low-level SevenBus IPC capability probe\",");
    printf("\"capabilities\":[");
    printf("{\"key\":\"unix_datagram_socketpair\",\"state\":\"%s\"},", state_for_bool(unix_ok));
    printf("{\"key\":\"unix_stream_socketpair\",\"state\":\"%s\"},", state_for_bool(stream_ok));
    printf("{\"key\":\"unix_seqpacket_socketpair\",\"state\":\"%s\"}", state_for_bool(seqpacket_ok));
    printf("],");
    printf("\"errno\":%d,", errno);
    printf("\"error\":\"%s\"", errno == 0 ? "" : strerror(errno));
    printf("}\n");
}

static void print_human(void) {
    printf("SevenBus C Probe\n");
    printf("================\n");
    printf("role: low-level IPC capability probe\n");
    printf("json: sevenbus-probe --json\n");
}

int main(int argc, char **argv) {
    int json = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--json") == 0 || strcmp(argv[i], "json") == 0) {
            json = 1;
        }
    }

    if (json) {
        print_json();
    } else {
        print_human();
    }

    return 0;
}
