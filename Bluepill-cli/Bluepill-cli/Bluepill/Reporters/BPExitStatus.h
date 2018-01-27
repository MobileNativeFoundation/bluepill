//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

// TODO: we're setting the exit status as consecutive integers but the code uses it like bitfields
typedef NS_ENUM(NSInteger, BPExitStatus) {
    BPExitStatusTestsAllPassed = 0,
    BPExitStatusTestsFailed = 1,
    BPExitStatusSimulatorCreationFailed = 2,
    BPExitStatusSimulatorCrashed = 3,
    BPExitStatusInstallAppFailed = 4,
    BPExitStatusLaunchAppFailed = 5,
    BPExitStatusTestTimeout = 6,
    BPExitStatusAppCrashed = 7,
    BPExitStatusInterrupted = 8,
    BPExitStatusSimulatorDeleted = 9,
    BPExitStatusUninstallAppFailed = 10,
    BPExitStatusSimulatorReuseFailed = 11,
    BPExitStatusAppHangsBeforeTestStart = 12,
};

// TODO: I think we whould rip out the BPExitStatusProtocol thingy
@protocol BPExitStatusProtocol <NSObject>

- (BOOL)isExecutionComplete;
- (BOOL)isApplicationLaunched;
- (BOOL)didTestsStart;

- (BPExitStatus)exitStatus;

@end

@interface BPExitStatusHelper : NSObject
// Exit status to string
+ (NSString *)stringFromExitStatus:(BPExitStatus)exitStatus;
@end
