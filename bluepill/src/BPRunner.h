//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "bp/src/BPXCTestFile.h"
#import "bp/src/BPConfiguration.h"

@interface BPRunner : NSObject

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) NSString *bpExecutable;
@property (nonatomic, strong) NSMutableArray *swimlaneList;
@property (nonatomic, strong) NSDictionary *testHostSimTemplates;

/*!
 * @discussion get a BPRunnner to run tests
 * @param config the config to run tests
 * @param bpPath the path to the Bp binary, if this is nil, we will search in the bluepill directory
 * @return return the BPRunner to start running tests
 */
+ (instancetype)BPRunnerWithConfig:(BPConfiguration *)config
                        withBpPath:(NSString *)bpPath;

/**
 @discussion start running tests
 @return 1: test failures 0: pass -1: failed to run tests
 */
- (int)runWithBPXCTestFiles:(NSArray<BPXCTestFile *>*)xcTestFiles;

- (void)interrupt;

- (NSUInteger)busySwimlaneCount;

@end
