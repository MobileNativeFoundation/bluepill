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

@class BPConfiguration;
@class BPSimulator;
@class BPTreeParser;

@interface BPExecutionContext : NSObject

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) BPSimulator *runner;
@property (nonatomic, strong) BPTreeParser *parser;
@property (nonatomic, assign) NSInteger attemptNumber;
@property (nonatomic, assign) BOOL simulatorCreated;
@property (nonatomic, assign) BOOL simulatorCrashed;
@property (nonatomic, assign) pid_t pid;
@property (nonatomic, assign) BOOL isTestRunnerContext;

// current run's exit status
@property (nonatomic, assign) BPExitStatus exitStatus;
// final exit status for this context run
@property (nonatomic, assign) BPExitStatus finalExitStatus;

@end
