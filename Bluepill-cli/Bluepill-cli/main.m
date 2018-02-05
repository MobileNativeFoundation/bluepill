//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "CoreSimulator.h"
#import "BPStats.h"
#import "BPWriter.h"
#import "BPConfiguration.h"
#import "Bluepill.h"
#import "BPUtils.h"
#import "SimulatorHelper.h"

#import <getopt.h>
#import <libgen.h>

int main(int argc, char * argv[]) {
    @autoreleasepool {
        // This next part is because we're weak-linking the private Xcode frameworks.
        // This is necessary in case you have multiple versions of Xcode so we dynamically
        // look at the path where Xcode is and add the private framework paths to the
        // DYLD_FALLBACK_FRAMEWORK_PATH environment variable.
        // We want to only do this once, so we use the BP_DYLD_RESOLVED environment variable
        // as a sentinel (geddit? sentinel!)
        
        if (getenv("BP_DYLD_RESOLVED") == NULL) {
            // Find path
            NSString *xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
            if (xcodePath == nil) {
                fprintf(stderr, "Failed to run `/usr/bin/xcode-select -print-path`.\n");
                return 1;
            }

            NSMutableArray *fallbackFrameworkPaths = [@[] mutableCopy];
            if (getenv("DYLD_FALLBACK_FRAMEWORK_PATH")) {
                [fallbackFrameworkPaths addObject:@(getenv("DYLD_FALLBACK_FRAMEWORK_PATH"))];
            } else {
                // If unset, this variable takes on an implicit default (see `man dyld`).
                [fallbackFrameworkPaths addObjectsFromArray:@[
                                          @"/Library/Frameworks",
                                          @"/Network/Library/Frameworks",
                                          @"/System/Library/Frameworks",
                                          ]];
            }

            [fallbackFrameworkPaths addObjectsFromArray:@[
                  [xcodePath stringByAppendingPathComponent:@"Library/PrivateFrameworks"],
                  [xcodePath stringByAppendingPathComponent:@"Platforms/MacOSX.platform/Developer/Library/Frameworks"],
                  [xcodePath stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks"],
                  [xcodePath stringByAppendingPathComponent:@"../OtherFrameworks"],
                  [xcodePath stringByAppendingPathComponent:@"../SharedFrameworks"],
                  ]];

            NSString *fallbackFrameworkPath = [fallbackFrameworkPaths componentsJoinedByString:@":"];
            setenv("DYLD_FALLBACK_FRAMEWORK_PATH", [fallbackFrameworkPath UTF8String], 1);

            // Don't do this setup again...
            setenv("BP_DYLD_RESOLVED", "YES", 1);
            execv(argv[0], (char *const *)argv);

            // we should never get here
            assert(!"FAIL");
        }
        
#pragma mark main
        int c;

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

        BPExitStatus exitCode;
        Bluepill *bp = [[Bluepill alloc] initWithConfiguration:config];
        exitCode = [bp run];
        if (config.outputDirectory) {
            NSString *fileName = [NSString stringWithFormat:@"%@-stats.txt", [[config.testBundlePath lastPathComponent] stringByDeletingPathExtension]];
            NSString *outputFile = [config.outputDirectory stringByAppendingPathComponent:fileName];
            BPWriter *statsWriter = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
            [[BPStats sharedStats] exitWithWriter:statsWriter exitCode:exitCode andCreateFullReport:YES];
            [[BPStats sharedStats] generateCSVreportWithPath:[NSString stringWithFormat:@"%@/bp.csv", config.outputDirectory]];
        }

        [BPUtils printInfo:INFO withString:@"BP exiting %ld", (long)exitCode];
        return exitCode;
    }
}
