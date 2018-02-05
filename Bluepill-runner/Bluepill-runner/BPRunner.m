//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPRunner.h"
#import "BPPacker.h"
#import "BPUtils.h"
#import "BPReportCollector.h"
#import "BPVersion.h"
#include <sys/sysctl.h>
#include <pwd.h>
#import <AppKit/AppKit.h>


static int volatile interrupted = 0;

void onInterrupt(int ignore) {
    interrupted ++;
}

int
numprocs(void)
{
    int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t len = 0;
    
    if (sysctl(mib, 4, NULL, &len, NULL, 0)) {
        perror("Failed to call sysctl");
        return 0;
    }
    return (int)len / sizeof(struct kinfo_proc);
}

int
maxprocs(void)
{
    int maxproc;
    size_t len = sizeof(maxproc);
    sysctlbyname("kern.maxproc", &maxproc, &len, NULL, 0);
    return maxproc;
}


@implementation BPRunner

+ (instancetype)BPRunnerWithConfig:(BPConfiguration *)config
                        withBpPath:(NSString *)bpPath {
    BPRunner *runner = [[BPRunner alloc] init];
    runner.config = config;
    // Find the `bp` binary.

    if (bpPath) {
        runner.bpExecutable = bpPath;
    } else {
        NSString *argv0 = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
        NSString *bp = [[argv0 stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"bp"];
        if (![[NSFileManager defaultManager] isExecutableFileAtPath:bp]) {
            // Search the PATH for a bp executable
            BOOL foundIt = false;
            NSString *path = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
            for (NSString *dir in [path componentsSeparatedByString:@":"]) {
                bp = [dir stringByAppendingPathComponent:@"bp"];
                if ([[NSFileManager defaultManager] isExecutableFileAtPath:bp]) {
                    foundIt = true;
                    break;
                }
            }
            if (!foundIt) {
                fprintf(stderr, "ERROR: I couldn't find the `bp` executable anywhere.\n"
                        "Please put it somewhere in your PATH. (Ideally next to `bluepill`.\n");
                return nil;
            }
        }
        runner.bpExecutable = bp;
    }
    return runner;
}

- (NSTask *)newTaskWithBundle:(BPXCTestFile *)bundle
                    andNumber:(NSUInteger)number
                    andDevice:(NSString *)deviceID
           andCompletionBlock:(void (^)(NSTask *))block {
    BPConfiguration *cfg = [self.config mutableCopy];
    assert(cfg);
    cfg.appBundlePath = bundle.UITargetAppPath ?: bundle.testHostPath;
    cfg.testBundlePath = bundle.testBundlePath;
    cfg.testRunnerAppPath = bundle.UITargetAppPath ? bundle.testHostPath : nil;
    cfg.testCasesToSkip = bundle.skipTestIdentifiers;
    cfg.commandLineArguments = bundle.commandLineArguments;
    cfg.environmentVariables = bundle.environmentVariables;
    cfg.useSimUDID = deviceID;
    cfg.keepSimulator = cfg.reuseSimulator;

    NSError *err;
    NSString *tmpFileName = [NSString stringWithFormat:@"%@/bluepill-%u-config",
                             NSTemporaryDirectory(),
                             getpid()];

    cfg.configOutputFile = [BPUtils mkstemp:tmpFileName withError:&err];
    if (!cfg.configOutputFile) {
        fprintf(stderr, "ERROR: %s\n", [[err localizedDescription] UTF8String]);
        return nil;
    }
    cfg.outputDirectory = [self.config.outputDirectory
                           stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"%lu", (unsigned long)number]];
    [cfg printConfig];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:self.bpExecutable];
    [task setArguments:@[@"-c", cfg.configOutputFile]];
    NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
    [env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
    [env setObject:[NSString stringWithFormat:@"%lu", number] forKey:@"_BP_NUM"];
    [task setEnvironment:env];
    [task setTerminationHandler:^(NSTask *task) {
        [[NSFileManager defaultManager] removeItemAtPath:cfg.configOutputFile
                                                   error:nil];
        [BPUtils printInfo:INFO withString:@"Simulator %lu (PID %u) has finished with exit code %d.",
                                            number, [task processIdentifier], [task terminationStatus]];
        block(task);
    }];
    return task;
}

- (NSTask *)newTaskToDeleteDevice:(NSString *)deviceID andNumber:(NSUInteger)number {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:self.bpExecutable];
    [task setArguments:@[@"-D", deviceID]];
    NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
    [env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
    [env setObject:[NSString stringWithFormat:@"%lu", number] forKey:@"_BP_NUM"];
    [task setEnvironment:env];
    
    [task setTerminationHandler:^(NSTask * _Nonnull task) {
        [BPUtils printInfo:INFO withString:@"Simulator %lu (PID %u) to delete device %@ has finished with exit code %d.",
         number, [task processIdentifier], deviceID, [task terminationStatus]];
    }];
    return task;
}

- (NSRunningApplication *)openSimulatorAppWithConfiguration:(BPConfiguration *)config andError:(NSError **)error {
    NSURL *simulatorURL = [NSURL fileURLWithPath:
                           [NSString stringWithFormat:@"%@/Applications/Simulator.app/Contents/MacOS/Simulator",
                            config.xcodePath]];
    
    NSWorkspaceLaunchOptions launchOptions = NSWorkspaceLaunchAsync |
                                             NSWorkspaceLaunchWithoutActivation |
                                             NSWorkspaceLaunchAndHide;
    //launch Simulator.app without booting a simulator
    NSDictionary *configuration = @{NSWorkspaceLaunchConfigurationArguments:@[@"-StartLastDeviceOnLaunch",@"0"]};
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace]
                                 launchApplicationAtURL:simulatorURL
                                 options:launchOptions
                                 configuration:configuration
                                 error:error];
    if (!app) {
        [BPUtils printInfo:ERROR withString:@"Launch Simulator.app returned error: %@", [*error localizedDescription]];
        return nil;
    }
    return app;
}


- (int)runWithBPXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    // Set up our SIGINT handler
    signal(SIGINT, onInterrupt);
    
    NSUInteger numSims = [self.config.numSims intValue];
    [BPUtils printInfo:INFO withString:@"This is Bluepill %s", BP_VERSION];
    NSError *error;
    NSMutableArray *bundles = [BPPacker packTests:xcTestFiles configuration:self.config andError:&error];
    if (!bundles || bundles.count == 0) {
        [BPUtils printInfo:ERROR withString:@"Packing failed: %@", [error localizedDescription]];
        return 1;
    }
    if (bundles.count < numSims) {
        [BPUtils printInfo:WARNING
                withString:@"Lowering number of simulators from %lu to %lu because there aren't enough tests.",
                            numSims, bundles.count];
    }
    [BPUtils printInfo:INFO withString:@"Running with %lu simulator%s.",
     (unsigned long)numSims, (numSims > 1) ? "s" : ""];
    NSArray *copyBundles = [NSMutableArray arrayWithArray:bundles];
    for (int i = 1; i < [self.config.repeatTestsCount integerValue]; i++) {
        [bundles addObjectsFromArray:copyBundles];
    }
    [BPUtils printInfo:INFO withString:@"Packed tests into %lu bundles", (unsigned long)[bundles count]];
    __block NSUInteger launchedTasks = 0;
    NSUInteger taskNumber = 0;
    __block int rc = 0;

    int maxProcs = maxprocs();
    int seconds = 0;
    __block NSMutableArray *taskList = [[NSMutableArray alloc] init];
    __block NSMutableArray *deviceList = [[NSMutableArray alloc] init];
    self.nsTaskList = [[NSMutableArray alloc] init];
    int old_interrupted = interrupted;
    NSRunningApplication *app;
    if (_config.headlessMode == NO) {
        app = [self openSimulatorAppWithConfiguration:_config andError:&error];
        if (!app) {
            [BPUtils printInfo:ERROR withString:@"Could not launch Simulator.app due to error: %@", [error localizedDescription]];
            return -1;
        }
    }
    while (1) {
        if (interrupted) {
            if (interrupted >=2) {
                [BPUtils printInfo:ERROR withString:@"You really want to terminate, OK!"];
                exit(0);
            }
            if (interrupted != old_interrupted) {
                [BPUtils printInfo:WARNING withString:@"Received interrupt (Ctrl-C) %d times, waiting for child processes to finish.", interrupted];
                old_interrupted = interrupted;
            }
            [self interrupt];
        }

        int noLaunchedTasks;
        int canLaunchTask;
        @synchronized (self) {
            noLaunchedTasks = (launchedTasks == 0);
            canLaunchTask = (launchedTasks < numSims);
        }
        if (noLaunchedTasks && (bundles.count == 0 || interrupted)) break;
        if (bundles.count > 0 && canLaunchTask && !interrupted) {
            NSString *deviceID = nil;
            @synchronized(self) {
                if ([deviceList count] > 0) {
                    deviceID = [deviceList objectAtIndex:0];
                    [deviceList removeObjectAtIndex:0];
                }
            }
            NSTask *task = [self newTaskWithBundle:[bundles objectAtIndex:0] andNumber:++taskNumber andDevice:deviceID andCompletionBlock:^(NSTask * _Nonnull task) {
                @synchronized (self) {
                    launchedTasks--;
                    if (self.config.reuseSimulator) {
                        NSString *deviceID = [self readSimUDIDFile:[task processIdentifier]];
                        if (deviceID) {
                            [deviceList addObject:deviceID];
                        }
                    }
                    [taskList removeObject:[NSString stringWithFormat:@"%lu", taskNumber]];
                    [self.nsTaskList removeObject:task];
                    rc = (rc || [task terminationStatus]);
                };
                [BPUtils printInfo:INFO withString:@"PID %d exited %d.", [task processIdentifier], [task terminationStatus]];
                rc = (rc || [task terminationStatus]);
            }];
            if (!task) {
                [BPUtils printInfo:ERROR withString:@"task is nil!"];
                exit(1);
            }
            [task launch];
            @synchronized(self) {
                [taskList addObject:[NSString stringWithFormat:@"%lu", taskNumber]];
                [self.nsTaskList addObject:task];
                [bundles removeObjectAtIndex:0];
                [BPUtils printInfo:INFO withString:@"Started Simulator %lu (PID %d).", taskNumber, [task processIdentifier]];
                launchedTasks++;
            }
        }
        sleep(1);
        if (seconds % 30 == 0) {
            NSString *listString;
            @synchronized (self) {
                listString = [taskList componentsJoinedByString:@", "];
            }
            [BPUtils printInfo:INFO withString:@"%lu Simulator%s still running. [%@]",
             launchedTasks, launchedTasks == 1 ? "" : "s", listString];
            if (numprocs() > maxProcs * BP_MAX_PROCESSES_PERCENT) {
                [BPUtils printInfo:INFO withString:@"Using %d of %d processes.", numprocs(), maxProcs];
                [BPUtils printInfo:WARNING withString:@"!!!The number of processes is more than  %f percent of maxProcs!!! it may fail with error: Unable to boot device due to insufficient system resources. Please check with system admin to restart this node and for proper mainantance routine", BP_MAX_PROCESSES_PERCENT*100];
                NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
                NSString *psLogFile = [NSString stringWithFormat:@"%@/allProcesses_%@.txt", self.config.outputDirectory, [dateFormatter stringFromDate:[NSDate date]]];
                [BPUtils printInfo:INFO withString:@"saving 'ps aux' command log to: %@", psLogFile];
                [BPUtils runShell:[NSString stringWithFormat:@"/bin/ps aux >> %@", psLogFile]];
            }
        }
        seconds += 1;
    }

    for (int i = 0; i < [deviceList count]; i++) {
        NSTask *task = [self newTaskToDeleteDevice:[deviceList objectAtIndex:i] andNumber:i+1];
        [task launch];
        //fire & forget, DON'T WAIT
    }
    
    [BPUtils printInfo:INFO withString:@"All simulators have finished."];
    // Process the generated report and create 1 single junit xml file.
    if (app) {
        [app terminate];
    }
    if (self.config.outputDirectory) {
        NSString *outputPath = [self.config.outputDirectory stringByAppendingPathComponent:@"TEST-FinalReport.xml"];
        NSFileManager *fm = [NSFileManager new];
        if ([fm fileExistsAtPath:outputPath]) {
            [fm removeItemAtPath:outputPath error:nil];
        }
        [BPReportCollector collectReportsFromPath:self.config.outputDirectory onReportCollected:^(NSURL *fileUrl) {
//            NSError *error;
//            NSFileManager *fm = [NSFileManager new];
//            [fm removeItemAtURL:fileUrl error:&error];
        } outputAtPath:outputPath];
    }

    if (self.config.outputDirectory) {
        NSString *outputPath = [self.config.outputDirectory stringByAppendingPathComponent:@"bluepill.csv"];
        NSFileManager *fm = [NSFileManager new];
        if ([fm fileExistsAtPath:outputPath]) {
            [fm removeItemAtPath:outputPath error:nil];
        }
        [BPReportCollector collectCSVFromPath:self.config.outputDirectory onReportCollected:^(NSURL *fileUrl) {
        } outputAtPath:outputPath];
    }
    
    return rc;
}

- (void)interrupt {
    if (self.nsTaskList == nil) return;
    
    for (int i = 0; i < [self.nsTaskList count]; i++) {
        [((NSTask *)[self.nsTaskList objectAtIndex:i]) interrupt];
    }
    
    [self.nsTaskList removeAllObjects];
}

- (NSString *)readSimUDIDFile:(int)pid {
    NSString *tempFileName = [NSString stringWithFormat:@"bluepill-deviceid.%d",pid];
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    
    NSError *error;
    NSString *idStr = [NSString stringWithContentsOfFile:tempFilePath encoding:NSUTF8StringEncoding error:&error];
    if (!idStr) {
        [BPUtils printInfo:ERROR withString:@"ERROR: Failed to read the device ID file %@ with error: %@", tempFilePath, [error localizedDescription]];
    }
    return idStr;
}
@end
