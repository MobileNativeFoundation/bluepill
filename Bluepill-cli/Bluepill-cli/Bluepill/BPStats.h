//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

#define CREATE_SIMULATOR(x)    [NSString stringWithFormat:@"[%lu] Create Simulator", (x)]
#define INSTALL_APPLICATION(x) [NSString stringWithFormat:@"[%lu] Install Application", (x)]
#define LAUNCH_APPLICATION(x)  [NSString stringWithFormat:@"[%lu] Launch Application", (x)]
#define RUN_TESTS(x)           [NSString stringWithFormat:@"[%lu] Run Tests", (x)]
#define DELETE_SIMULATOR(x)    [NSString stringWithFormat:@"[%lu] Delete Simulator", (x)]

#define ALL_TESTS              @"All Tests"
#define TEST_CASE_FORMAT       @"[%lu] [%@/%@]"
#define TEST_SUITE_FORMAT      @"[%lu] {[%@]}"

@class BPWriter;

@interface BPStats : NSObject

@property (nonatomic, assign) NSInteger attemptNumber;
@property (nonatomic, assign) BOOL cleanRun;

+ (instancetype)sharedStats;

- (void)startTimer:(NSString *)name;
- (void)endTimer:(NSString *)name;
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
- (void)addSimulatorDeleteFailure;
- (void)addSimulatorInstallFailure;
- (void)addSimulatorLaunchFailure;

- (void)exitWithWriter:(BPWriter *)writer exitCode:(int)exitCode andCreateFullReport:(BOOL)fullReport;

@end
