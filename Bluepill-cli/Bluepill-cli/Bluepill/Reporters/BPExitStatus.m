//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPExitStatus.h"


@implementation BPExitStatusHelper

// Exit status to string
+ (NSString *)stringFromExitStatus:(BPExitStatus)exitStatus {
    switch (exitStatus) {
        case BPExitStatusTestsAllPassed:
            return @"BPExitStatusTestsAllPassed";
        case BPExitStatusTestsFailed:
            return @"BPExitStatusTestsFailed";
        case BPExitStatusSimulatorCreationFailed:
            return @"BPExitStatusSimulatorCreationFailed";
        case BPExitStatusSimulatorCrashed:
            return @"BPExitStatusSimulatorCrashed";
        case BPExitStatusLaunchAppFailed:
            return @"BPExitStatusLaunchAppFailed";
        case BPExitStatusTestTimeout:
            return @"BPExitStatusTestTimeout";
        case BPExitStatusAppCrashed:
            return @"BPExitStatusAppCrashed";
        case BPExitStatusInstallAppFailed:
            return @"BPExitStatusInstallAppFailed";
        case BPExitStatusInterrupted:
            return @"BPExitStatusInterrupted";
        case BPExitStatusSimulatorDeleted:
            return @"BPExitStatusSimulatorDeleted";
        case BPExitStatusSimulatorReuseFailed:
            return @"BPExitStatusSimulatorReuseFailed";
        case BPExitStatusAppHangsBeforeTestStart:
            return @"BPExitStatusAppHangsBeforeTestStart";
        default:
            return @"UNKNOWN_BPEXITSTATUS";
    }
}

@end
