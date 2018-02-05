//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

#define CREATE_SIMULATOR(x)      [NSString stringWithFormat:@"[Attempt %lu] Create Simulator", (x)]
#define REUSE_SIMULATOR(x)       [NSString stringWithFormat:@"[Attempt %lu] Reuse Simulator", (x)]
#define INSTALL_APPLICATION(x)   [NSString stringWithFormat:@"[Attempt %lu] Install Application", (x)]
#define UNINSTALL_APPLICATION(x) [NSString stringWithFormat:@"[Attempt %lu] Uninstall Application", (x)]
#define LAUNCH_APPLICATION(x)    [NSString stringWithFormat:@"[Attempt %lu] Launch Application", (x)]
#define TOTAL_TEST_TIME(x)             [NSString stringWithFormat:@"[Attempt %lu] Total Test Time(including clean-up after test)", (x)]
#define DELETE_SIMULATOR(x)      [NSString stringWithFormat:@"[Attempt %lu] Delete Simulator", (x)]
#define DELETE_SIMULATOR_CB(x)   [NSString stringWithFormat:@"[Attempt %lu] Delete Simulator due to BAD STATE", (x)]

#define TEST_CASE_FORMAT       @"[Attempt %lu] [%@/%@]"
#define TEST_SUITE_FORMAT      @"[Attempt %lu] {[%@]}"

@class BPWriter;

@interface BPStats : NSObject

@property (nonatomic, assign) NSInteger attemptNumber;
@property (nonatomic, assign) BOOL cleanRun;

+ (instancetype)sharedStats;

- (void)startTimer:(NSString *)name;
- (void)startTimer:(NSString *)name withAttemptNumber:(NSInteger)attemptNumber;
- (void)endTimer:(NSString *)name withErrorMessage: (NSString *)errorMessage;
- (void)outputTimerStats:(NSString *)name toWriter:(BPWriter *)writer;

- (void)addTest;
- (void)addTestFailure;
- (void)addTestError;
- (void)addSimulatorCrash;
- (void)addApplicationCrash;
- (void)addRetry;
- (void)addTestRuntimeTimeout;
- (void)addTestOutputTimeout;
- (void)addSimulatorCreateFailure;
- (void)addSimulatorReuseFailure;
- (void)addSimulatorDeleteFailure;
- (void)addSimulatorInstallFailure;
- (void)addSimulatorLaunchFailure;
- (void)generateCSVreportWithPath:(NSString *)path;

- (void)exitWithWriter:(BPWriter *)writer exitCode:(int)exitCode andCreateFullReport:(BOOL)fullReport;

@end
