//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "Bluepill.h"
#import "BPConfiguration.h"
#import "BPSimulator.h"
#import "BPUtils.h"
#import "SimulatorHelper.h"
#import "BPStats.h"
#import "BPWriter.h"

#import <getopt.h>
#import <libgen.h>

int main(int argc, char * argv[]) {
    @autoreleasepool {
        int rc = [BPUtils setupWeakLinking:argc argv:argv];
        if (rc != 0) return rc;
#pragma mark main
        int c;

        if (argv[1] && (!strcmp(argv[1], "version") || (!strcmp(argv[1], "--version")))) {
            printf("Bluepill %s\n", [BPUtils version]);
            exit(0);
        }

        BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];

        
        struct option *lopts = [config getLongOptions];
        char *sopts = [config getShortOptions];

        [BPStats sharedStats]; // Create the BPStats object. This records our start time.

        config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
        [SimulatorHelper loadFrameworksWithXcodePath:config.xcodePath];

        // We don't do any processing here, just save the args and let BPConfiguration
        // process/validate later.
        while ((c = getopt_long(argc, argv, sopts, lopts, NULL)) != -1) {
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
        err = nil;
        if (![config fillSimDeviceTypeAndRuntimeWithError:&err]) {
            fprintf(stderr, "%s: Unable to fill Sim device type and/or runtime\n\t%s\n",
                    basename(argv[0]), [[err localizedDescription] UTF8String]);
            exit(1);
        }

        BPExitStatus exitCode;
        Bluepill *bp = [[Bluepill alloc] initWithConfiguration:config];
        exitCode = [bp run];
        if (config.outputDirectory) {
            NSString *fileName = [NSString stringWithFormat:@"%@-stats.json", [[config.testBundlePath lastPathComponent] stringByDeletingPathExtension]];
            NSString *outputFile = [config.outputDirectory stringByAppendingPathComponent:fileName];
            BPWriter *statsWriter = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
            [[BPStats sharedStats] exitWithWriter:statsWriter exitCode:(int)exitCode];
        }

        [BPUtils printInfo:INFO withString:@"BP exiting %ld", (long)exitCode];
        return (int)exitCode;
    }
}
