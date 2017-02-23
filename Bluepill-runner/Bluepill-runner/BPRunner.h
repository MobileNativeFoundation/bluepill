//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPApp.h"
#import "BPConfiguration.h"

@interface BPRunner : NSObject

@property (nonatomic, strong, nonnull) BPConfiguration *config;
@property (nonatomic, strong, nonnull) BPApp *app;
@property (nonatomic, strong, nonnull) NSString *bpExecutable;
@property (nonatomic, strong,nonnull) NSMutableArray *nsTaskList;
/*!
 * @discussion get a BPRunnner to run tests
 * @param app the BPapp
 * @param config the config to run tests
 * @param bpPath the path to the Bp binary, if this is nil, we will search in the bluepill directory
 * @return return the BPRunner to start running tests
 */
+ (instancetype _Nullable )BPRunnerForApp:( BPApp * _Nonnull )app
                               withConfig:(BPConfiguration * _Nonnull)config
                               withBpPath:(NSString * _Nullable)bpPath;


/*!
 * @discussion Create a new Simulator wrapped in a `bp` process. It will run the specified bundle and execute the block once it finishes.
 * @param bundle The test bundle to execute.
 * @param number The simulator number (will be printed in logs).
 * @param block A completion block to execute when the NSTask has finished.
 * @return An NSTask ready to be executed via [task launch] or nil in failure.
 *
 */
- (NSTask * _Nonnull)newTaskWithBundle:(NSArray * _Nonnull)bundle andNumber:(NSUInteger)number andCompletionBlock:(void (^_Nonnull)(NSTask * _Nonnull))block;

/**
 @discussion start running tests
 @return 1: test failures 0: pass -1: failed to run tests
 */
- (int)run;

- (void) interrupt;

@end
