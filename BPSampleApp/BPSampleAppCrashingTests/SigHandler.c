//
//  SigHandler.c
//  BPSampleAppCrashingTests
//
//  Created by Oscar Bonilla on 1/10/18.
//  Copyright © 2018 LinkedIn. All rights reserved.
//

#include "SigHandler.h"
#include <sys/signal.h>
#include <signal.h>
#include <execinfo.h>
#include <pthread.h>
#include <string.h>
#include <stdlib.h>

pthread_mutex_t handlerMutex;

// Catch BSD signals and report stacktrace on first catch
void mysighandler(int sig, siginfo_t *info, void *context)
{
    pthread_mutex_lock(&handlerMutex);
    static int firstCall = 1;
    if (firstCall) { // report only first signal
        fprintf(stderr, "stack trace for SIGNAL %d (%s):\n", sig, strsignal(sig));

        void *backtraceFrames[128];
        int frameCount = backtrace(backtraceFrames, 128);

        // report the error
        char** strs = backtrace_symbols(backtraceFrames, frameCount);
        for (int i = 0; i < frameCount; ++i) {
            fprintf(stderr, "%s\n", strs[i]);
        }
        free(strs);
        firstCall = 0;
    }
    signal(sig, SIG_DFL);
    pthread_mutex_unlock(&handlerMutex);
    raise(sig);
}

// Initialize signals handler with 'mysighandler'
void initsighandler()
{
    pthread_mutex_init(&handlerMutex, NULL);
    struct sigaction mySigAction;
    mySigAction.sa_sigaction = mysighandler;
    mySigAction.sa_flags = SA_SIGINFO;
    sigemptyset(&mySigAction.sa_mask);
    int signal[] = {
        SIGHUP, SIGINT, SIGQUIT, SIGILL, SIGTRAP,
        SIGABRT, SIGEMT, SIGFPE, SIGBUS,
        SIGSEGV, SIGSYS, SIGPIPE, SIGALRM, SIGTERM,
        SIGTSTP,
        SIGTTIN, SIGTTOU, SIGXCPU, SIGXFSZ,
        SIGVTALRM, SIGPROF, SIGUSR1,
        SIGUSR2
    };
    for (int i = 0; i <  sizeof(signal) / sizeof(int); i++) { // apply handler to all signals in signal.h which terminate process
        sigaction(signal[i], &mySigAction, NULL);
    }
}
