#define _POSIX_C_SOURCE 200809L
#include <signal.h>
#include <stddef.h>
#include "termination.h"
static volatile sig_atomic_t stopping;
static void request_stop(int signal_number) {
    (void)signal_number;
    stopping = 1;
}
int narthex_install_termination(void) {
    struct sigaction action;
    action.sa_handler = request_stop;
    sigemptyset(&action.sa_mask);
    action.sa_flags = 0;
    stopping = 0;
    if (sigaction(SIGTERM, &action, NULL) != 0) return -1;
    if (sigaction(SIGINT, &action, NULL) != 0) return -1;
    return 0;
}
int narthex_stop_requested(void) { return stopping != 0; }
