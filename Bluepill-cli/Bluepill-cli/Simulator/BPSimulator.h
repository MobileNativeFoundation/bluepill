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
#import "SimulatorScreenshotService.h"

@class BPConfiguration;
@class BPTreeParser;
@class SimDevice;

@interface BPSimulator : NSObject

@property (nonatomic, strong) SimulatorMonitor *monitor;
@property (nonatomic, strong) SimulatorScreenshotService *screenshotService;
@property (nonatomic, assign, readonly) BOOL needsRetry;
@property (nonatomic, readonly) NSString *UDID;
@property (nonatomic, strong) SimDevice *device;

+ (instancetype)simulatorWithConfiguration:(BPConfiguration *)config;

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion;

- (BOOL)useSimulatorWithDeviceUDID:(NSUUID *)deviceUDID withError:(NSError **)error;

- (BOOL)uninstallApplicationAndReturnError:(NSError **)error;

- (void)bootWithCompletion:(void (^)(NSError *error))completion;

- (BOOL)installApplicationAndReturnError:(NSError *__autoreleasing *)error;

- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser forAttempt:(NSInteger)attemptNumber andCompletion:(void (^)(NSError *, pid_t))completion;

- (void)deleteSimulatorWithCompletion:(void (^)(NSError *error, BOOL success))completion;

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
