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
#import <getopt.h>
#import <libgen.h>


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

        struct option *lopts = [BPConfiguration getLongOptions];
        char *sopts = [BPConfiguration getShortOptions];
       
        while((c = getopt_long(argc, argv, sopts, lopts, NULL)) != -1) {
            if (!optarg) optarg = "";
            [config saveOpt:[NSNumber numberWithInt:c] withArg:[NSString stringWithUTF8String:optarg]];
        }
        free(lopts);
        free(sopts);

        if (argv[optind] && !strcmp(argv[optind], "version")) {
            printf("Bluepill %s\n", BP_VERSION);
            exit(0);
        }

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

        // start a runner and let it fly
        BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:config withBpPath:nil];
        exit([runner run]);
    }
    return 0;
}

void usage(void) {
    printf("Usage: bluepill -c <config> -a <path_to_app_bundle>\n");
    exit(0);
}
