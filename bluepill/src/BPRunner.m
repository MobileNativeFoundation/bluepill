//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <AppKit/AppKit.h>
#import "bp/src/BPCreateSimulatorHandler.h"
#import "bp/src/BPSimulator.h"
#import "bp/src/BPStats.h"
#import "bp/src/BPUtils.h"
#import "bp/src/BPWaitTimer.h"
#import "bp/src/SimulatorHelper.h"
#import "BPPacker.h"
#import "BPRunner.h"
#import "BPSwimlane.h"

#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/processor_info.h>
#include <pwd.h>
#include <signal.h>
#include <sys/sysctl.h>
#include <sys/types.h>

static int volatile interrupted = 0;

static void onInterrupt(int ignore) {
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
    runner.testHostSimTemplates = [[NSMutableDictionary alloc] init];
    runner.config = config;
    runner.bpExecutable = bpPath ?: [BPUtils findExecutablePath:@"bp"];
    if (!runner.bpExecutable) {
        fprintf(stderr, "ERROR: Unable to find bp executable.\n");
        return nil;
    }
    return runner;
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
        [BPUtils printInfo:INFO withString:@"BP-%lu (PID %u) to delete device %@ has finished with exit code %d.",
         number, [task processIdentifier], deviceID, [task terminationStatus]];
    }];
    return task;
}

- (NSRunningApplication *)openSimulatorAppWithConfiguration:(BPConfiguration *)config andError:(NSError **)errPtr {
    NSURL *simulatorURL = [NSURL fileURLWithPath:
                           [NSString stringWithFormat:@"%@/Applications/Simulator.app/Contents/MacOS/Simulator",
                            config.xcodePath]];

    NSWorkspaceLaunchOptions launchOptions = NSWorkspaceLaunchAsync |
                                             NSWorkspaceLaunchWithoutActivation |
                                             NSWorkspaceLaunchAndHide;
    //launch Simulator.app without booting a simulator
    NSDictionary *configuration = @{NSWorkspaceLaunchConfigurationArguments:@[@"-StartLastDeviceOnLaunch",@"0"]};
    NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:simulatorURL
                                                                              options:launchOptions
                                                                        configuration:configuration
                                                                                error:errPtr];
    if (!app) {
        [BPUtils printInfo:ERROR withString:@"Launch Simulator.app returned error: %@", [*errPtr localizedDescription]];
        return nil;
    }
    return app;
}

- (int)runWithBPXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    // Set up our SIGINT handler
    struct sigaction new_action;
    new_action.sa_handler = onInterrupt;
    sigemptyset(&new_action.sa_mask);
    new_action.sa_flags = 0;

    if (sigaction(SIGINT, &new_action, NULL) != 0) {
        [BPUtils printInfo:ERROR withString:@"Could not install SIGINT handler: %s", strerror(errno)];
    }
    if (sigaction(SIGTERM, &new_action, NULL) != 0) {
        [BPUtils printInfo:ERROR withString:@"Could not install SIGTERM handler: %s", strerror(errno)];
    }
    if (sigaction(SIGHUP, &new_action, NULL) != 0) {
        [BPUtils printInfo:ERROR withString:@"Could not install SIGHUP handler: %s", strerror(errno)];
    }
    BPSimulator *bpSimulator = [BPSimulator simulatorWithConfiguration:self.config];
    NSUInteger numSims = [self.config.numSims intValue];
    [BPUtils printInfo:INFO withString:@"This is Bluepill %s", [BPUtils version]];
    NSError *error;
    NSMutableArray<BPXCTestFile *> *bundles = [[BPPacker packTests:xcTestFiles configuration:self.config andError:&error] mutableCopy];
    if (!bundles || bundles.count == 0) {
        [BPUtils printInfo:ERROR withString:@"Packing failed: %@", [error localizedDescription]];
        return 1;
    }
    if (bundles.count < numSims) {
        [BPUtils printInfo:WARNING
                withString:@"Lowering number of parallel simulators from %lu to %lu because there aren't enough test bundles.",
                            numSims, bundles.count];
        numSims = bundles.count;
    }
    if (self.config.cloneSimulator) {
        self.testHostSimTemplates = [bpSimulator createSimulatorAndInstallAppWithBundles:xcTestFiles];
        if ([self.testHostSimTemplates count] == 0) {
            return 1;
        }
    }
    [BPUtils printInfo:INFO withString:@"Running with %lu %s.",
     (unsigned long)numSims, (numSims > 1) ? "parallel simulators" : "simulator"];
    NSArray *copyBundles = [bundles copy];
    for (int i = 1; i < [self.config.repeatTestsCount integerValue]; i++) {
        [bundles addObjectsFromArray:copyBundles];
    }
    [BPUtils printInfo:INFO withString:@"Packed tests into %lu bundles", (unsigned long)[bundles count]];
    NSUInteger taskNumber = 0;
    __block int rc = 0;

    self.swimlaneList = [[NSMutableArray alloc] initWithCapacity:numSims];
    for (NSUInteger i = 1; i <= numSims; i++) {
        BPSwimlane *swimlane = [BPSwimlane BPSwimlaneWithLaneID:i];
        [self.swimlaneList addObject:swimlane];
    }

    int maxProcs = maxprocs();
    int seconds = 0;
    __block NSMutableArray *deviceList = [[NSMutableArray alloc] init];
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
            if (interrupted >=5) {
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
            NSUInteger busySwimlaneCount = [self busySwimlaneCount];
            noLaunchedTasks = (busySwimlaneCount == 0);
            canLaunchTask = (busySwimlaneCount < numSims);
        }
        if (noLaunchedTasks && (bundles.count == 0 || interrupted)) break;
        if (bundles.count > 0 && canLaunchTask && !interrupted) {
            NSString *deviceID = nil;
            BPSwimlane *swimlane = nil;
            @synchronized(self) {
                if ([deviceList count] > 0) {
                    deviceID = [deviceList objectAtIndex:0];
                    [deviceList removeObjectAtIndex:0];
                }
                swimlane = [self firstIdleSwimlane];
                swimlane.isBusy = YES;
            }
            BPXCTestFile *bundle = [bundles objectAtIndex:0];
            [swimlane launchTaskWithBundle:bundle
                                 andConfig:self.config
                             andLaunchPath:self.bpExecutable
                                 andNumber:++taskNumber
                                 andDevice:deviceID
                        andTemplateSimUDID:self.testHostSimTemplates[bundle.testHostPath]
                        andCompletionBlock:^(NSTask * _Nonnull task) {
                @synchronized (self) {
                    rc = (rc || [task terminationStatus]);
                };
                [BPUtils printInfo:INFO withString:@"PID %d exited %d.", [task processIdentifier], [task terminationStatus]];
                rc = (rc || [task terminationStatus]);
            }];
            @synchronized(self) {
                [bundles removeObjectAtIndex:0];
            }
        }
        sleep(1);
        if (seconds % 30 == 0) {
            NSString *listString;
            NSUInteger launchedTasks = 0;
            @synchronized (self) {
                NSMutableArray *taskNumberList = [[NSMutableArray alloc] init];
                for (BPSwimlane *swimlane in self.swimlaneList) {
                    if (swimlane.isBusy) {
                        launchedTasks++;
                        [taskNumberList addObject:[NSString stringWithFormat:@"%lu", swimlane.taskNumber]];
                    }
                }
                listString = [taskNumberList componentsJoinedByString:@", "];
            }
            [BPUtils printInfo:INFO withString:@"%lu BP(s) still running. [%@]", launchedTasks, listString];
            [BPUtils printInfo:INFO withString:@"Using %d of %d processes.", numprocs(), maxProcs];
            if (numprocs() > maxProcs * BP_MAX_PROCESSES_PERCENT) {
                [BPUtils printInfo:WARNING withString:@"!!!The number of processes is more than  %f percent of maxProcs!!! it may fail with error: Unable to boot device due to insufficient system resources. Please check with system admin to restart this node and for proper mainantance routine", BP_MAX_PROCESSES_PERCENT*100];
                NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
                [dateFormatter setDateFormat:@"yyyy-MM-dd_HH-mm-ss"];
                NSString *psLogFile = [NSString stringWithFormat:@"%@/allProcesses_%@.txt", self.config.outputDirectory, [dateFormatter stringFromDate:[NSDate date]]];
                [BPUtils printInfo:INFO withString:@"saving 'ps aux' command log to: %@", psLogFile];
                [BPUtils runShell:[NSString stringWithFormat:@"/bin/ps aux >> %@", psLogFile]];
            }
        }
        seconds += 1;
        [self addCounters];
    }

    for (int i = 0; i < [deviceList count]; i++) {
        NSTask *task = [self newTaskToDeleteDevice:[deviceList objectAtIndex:i] andNumber:i+1];
        [task launch];
        //fire & forget, DON'T WAIT
    }

    [BPUtils printInfo:INFO withString:@"All BPs have finished."];
    if (self.config.cloneSimulator) {
        [BPUtils printInfo:INFO withString:@"Deleting template simulator.."];
        [bpSimulator deleteTemplateSimulator];
    }
    // Process the generated report and create 1 single junit xml file.
    if (app) {
        [app terminate];
    }
    return rc;
}

- (void)interrupt {
    if (self.swimlaneList == nil) return;

    for (BPSwimlane *swimlane in self.swimlaneList) {
        [swimlane interrupt];
    }
}

- (void)addCounters {
    // get CPU info
    static uint64 lastSystemTime = 0, lastUserTime = 0, lastIdleTime = 0;
    processor_cpu_load_info_t cpuLoad;
    mach_msg_type_number_t count;
    natural_t procCount;
    kern_return_t kr;

    kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &procCount, (processor_info_array_t *)&cpuLoad, &count);
    if (kr == KERN_SUCCESS) {
        uint64 totalSystemTime = 0, totalUserTime = 0, totalIdleTime = 0;
        for (natural_t i = 0; i < procCount ; ++i) {
            uint64_t system = 0, user = 0, idle = 0;
            system = cpuLoad[i].cpu_ticks[CPU_STATE_SYSTEM];
            user = cpuLoad[i].cpu_ticks[CPU_STATE_USER] + cpuLoad[i].cpu_ticks[CPU_STATE_NICE];
            idle = cpuLoad[i].cpu_ticks[CPU_STATE_IDLE];
            totalSystemTime += system;
            totalUserTime += user;
            totalIdleTime += idle;
        }
        if (lastSystemTime != 0) {
            uint64_t system = totalSystemTime - lastSystemTime;
            uint64_t user = totalUserTime - lastUserTime;
            uint64_t idle = totalIdleTime - lastIdleTime;

            uint64_t total = system + user + idle;

            double onePercent = total/100.0f;
            [[BPStats sharedStats] addCounter:@"CPU" withValues:@{
                                                                  @"sys": @((double)system/onePercent),
                                                                  @"usr": @((double)user/onePercent),
                                                                  @"idle": @((double)idle/onePercent)
                                                                  }];
        }
        lastSystemTime = totalSystemTime;
        lastUserTime = totalUserTime;
        lastIdleTime = totalIdleTime;
    } else {
        [BPUtils printInfo:ERROR withString:@"Failed to get CPU stats: %s", mach_error_string(kr)];
    }
    // get memory info
    count = HOST_VM_INFO_COUNT;
    vm_statistics_data_t vmstat;
    kr = host_statistics(mach_host_self(), HOST_VM_INFO, (host_info_t)&vmstat, &count);
    if(kr == KERN_SUCCESS) {
        double total = vmstat.wire_count + vmstat.active_count + vmstat.inactive_count + vmstat.free_count;
        double wired = vmstat.wire_count / total;
        double active = vmstat.active_count / total;
        double inactive = vmstat.inactive_count / total;
        double free = vmstat.free_count / total;

        [[BPStats sharedStats] addCounter:@"Memory" withValues:@{
                                                                 @"wired": @(wired * 100.0f),
                                                                 @"active": @(active * 100.0f),
                                                                 @"inactive": @(inactive * 100.0f),
                                                                 @"free": @(free * 100.0f)
                                                                 }];
    } else {
        [BPUtils printInfo:ERROR withString:@"Failed to get Memory info: %s", mach_error_string(kr)];
    }
}

- (NSUInteger)busySwimlaneCount {
    NSUInteger count = 0;
    for (BPSwimlane *swimlane in self.swimlaneList) {
        if (swimlane.isBusy) {
            count++;
        }
    }
    return count;
}

- (BPSwimlane *)firstIdleSwimlane {
    for (BPSwimlane *swimlane in self.swimlaneList) {
        if (!swimlane.isBusy) {
            return swimlane;
        }
    }
    return nil;
}

@end
