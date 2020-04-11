//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BPExitStatus) {
    BPExitStatusAllTestsPassed          = 0,
    BPExitStatusTestsFailed             = 1 << 0,
    BPExitStatusSimulatorCreationFailed = 1 << 1,
    BPExitStatusInstallAppFailed        = 1 << 2,
    BPExitStatusInterrupted             = 1 << 3,
    BPExitStatusSimulatorCrashed        = 1 << 4,
    BPExitStatusLaunchAppFailed         = 1 << 5,
    BPExitStatusTestTimeout             = 1 << 6,
    BPExitStatusAppCrashed              = 1 << 7,
    BPExitStatusSimulatorDeleted        = 1 << 8,
    BPExitStatusUninstallAppFailed      = 1 << 9,
    BPExitStatusSimulatorReuseFailed    = 1 << 10
};

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
