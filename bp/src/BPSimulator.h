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
#import "SimulatorMonitor.h"
#import "BPXCTestFile.h"

@class BPConfiguration;
@class BPTreeParser;
@class SimDevice;
@class BPTestCaseInfo;

@interface BPSimulator : NSObject

@property (nonatomic, strong) SimulatorMonitor *monitor;
@property (nonatomic, assign, readonly) BOOL needsRetry;
@property (nonatomic, readonly) NSString *UDID;
@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) NSURL *preferencesFile;

+ (instancetype)simulatorWithConfiguration:(BPConfiguration *)config;

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion;

- (void)cloneSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion;

- (void)setParserStateCompleted;

- (BOOL)useSimulatorWithDeviceUDID:(NSUUID *)deviceUDID;

- (BOOL)uninstallApplicationWithError:(NSError **)errPtr;

- (void)bootWithCompletion:(void (^)(NSError *error))completion;

- (BOOL)installApplicationWithError:(NSError *__autoreleasing *)errPtr;

- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser andCompletion:(void (^)(NSError *, pid_t))completion;

/**
 Launches a process which inspects a test bundle, and calls a completion block with a list of all tests in the bundle.

 @discussion The only way to do this is to actually launch a test execution with an injected Bluepill module. This module
 then checks what test cases exist at runtime, and writes these cases to a file before ending the process (such that no tests are actually run).
 We then read that file, and pass the results to the completion handler provided.
 */
- (void)collectTestSuiteInfoWithCompletion:(void (^)(NSArray<BPTestCaseInfo *> *, NSError *))completionBlock;

/**
 Executes logic tests for the provided context, providing two callbacks as the execution starts and finishes.
 @param parser The test log parser
 @param spawnBlock Called once the process is spawned (right after it's started and the process is actually running)
 @param completionBlock Called once the process completes, and all tests have either passed/failed/erred.
 */
- (void)executeLogicTestsWithParser:(BPTreeParser *)parser
                            onSpawn:(void (^)(NSError *, pid_t))spawnBlock
                      andCompletion:(void (^)(NSError *, pid_t))completionBlock;

- (void)deleteSimulatorWithCompletion:(void (^)(NSError *error, BOOL success))completion;

- (void)addPhotosToSimulator;

- (void)addVideosToSimulator;

- (void)runScriptFile:(NSString *)scriptFilePath;

/*!
 @discussion create template simulators and install the test hosts
 @param testBundles include the test hosts need to be installed.
 The number of template simulators is equal to the number of test hosts
 @return a dictionary with key to be the host bundle path and value to be the template simulator
 */
- (NSMutableDictionary*)createSimulatorAndInstallAppWithBundles:(NSArray<BPXCTestFile *>*)testBundles;

- (void)deleteTemplateSimulator;

/*!
 * @discussion returns true if the simulator is still running -- useful for detecting simulator crashes
 */
- (BOOL)isSimulatorRunning;

/*!
 * @discussion returns true if all execution is completed, false otherwise.
 */
- (BOOL)isFinished;
- (BOOL)needsRetry;
- (BPExitStatus)exitStatus;
- (BOOL)isApplicationLaunched;
@end
