//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPApp.h"
#import "BPConfiguration.h"
#import "BPRunner.h"
#import "BPVersion.h"
#import "BPUtils.h"
#import <getopt.h>
#import <libgen.h>

#include <sys/ioctl.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>

void m() {
    char *s="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()";
    srandom((unsigned int)time(0));printf("\e[1;40m");printf("\e[1;1H\e[2J");
    struct winsize w;ioctl(0, TIOCGWINSZ, &w);int x = w.ws_row; int y = w.ws_col;
    if (!(x && y)) return; int *a = malloc(y * sizeof(int));
    for (int i=0; i < y; i++) a[i] = -1;
    for (int k = 0; k < 500; k++) {
        int c = random() % 72; char l = s[c];
        int j = random() % y; a[j] = 0;
        for (int i = 0; i < y; i++) {
            if (a[i] == -1) continue;
            int o = a[i]; a[i]++;
            printf("\033[%d;%dH\033[2;32m%c\033[%d;%dH\033[1;37m%c\033[0;0H",o,i,l,a[i],i,l);
            if (a[i] >= x) a[i] = 0;
        }
        usleep(5000);
    }
    free(a);
    printf("\e[1;40m\e[1;1H\e[2J");
}

void usage(void);


struct options {
    char    *app;       // name of the application to test
    long     num_sims;   // how many parallel simulators to run
    char    *config;    // configuration file for each simulator.
};

int main(int argc, char * argv[]) {
    @autoreleasepool {
        int c;
        BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
        struct option *lopts = [config getLongOptions];
        char *sopts = [config getShortOptions];
        if (argv[1] && (!strcmp(argv[1], "version") || (!strcmp(argv[1], "--version")))) {
            printf("Bluepill %s\n", BP_VERSION);
            exit(0);
        }

        if (argv[1] && (!strcmp(argv[1], "--matrix"))) {
            m();
            exit(0);
        }

        while((c = getopt_long(argc, argv, sopts, lopts, NULL)) != -1) {
            if (!optarg) optarg = "";
            [config saveOpt:[NSNumber numberWithInt:c] withArg:[NSString stringWithUTF8String:optarg]];
        }
        free(lopts);
        free(sopts);

        NSError *err = nil;
        if (![config processOptionsWithError:&err] || ![config validateConfigWithError:&err]) {
            fprintf(stderr, "%s: invalid configuration\n\t%s\n",
                    basename(argv[0]), [[err localizedDescription] UTF8String]);
            exit(1);
        }

        BPApp *app = [BPApp appWithConfig:config withError:&err];
        if (!app) {
            fprintf(stderr, "ERROR: %s\n", [[err localizedDescription] UTF8String]);
            exit(1);
        }
        if (config.listTestsOnly) {
            [app listTests];
            exit(0);
        }

        BPConfiguration *normalizedConfig = [BPUtils normalizeConfiguration:config withTestFiles:app.testBundles];
        // start a runner and let it fly
        BPRunner *runner = [BPRunner BPRunnerWithConfig:normalizedConfig withBpPath:nil];
        exit([runner runWithBPXCTestFiles:app.testBundles]);
    }
    return 0;
}

void usage(void) {
    printf("Usage: bluepill -c <config> -a <path_to_app_bundle>\n");
    exit(0);
}
