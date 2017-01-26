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
@class BPTreeParser;
@class SimDevice;

@interface SimulatorRunner : NSObject

@property (nonatomic, assign, readonly) BOOL needsRetry;
@property (nonatomic, readonly) NSString *UDID;


+ (instancetype)simulatorRunnerWithConfiguration:(BPConfiguration *)config;

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion;
- (void)deleteSimulatorWithCompletion:(void (^)(NSError *error, BOOL success))completion;
- (BOOL)useSimulatorWithDeviceID:(NSUUID *)deviceID;

///*!
// * @discussion install an app in a specified simulator
// * @param hostBundleID the bundleID of the app to be installed in the simulator
// * @param hostBundlePath the path to the app (/debug-simulator/ABC.app)
// * @param device the device that the app will be installed in
// * @param error the error information
// * @return return whether the installation is successful or not
// */
//+ (BOOL)installAppWithBundleID:(NSString *)hostBundleID
//                    bundlePath:(NSString *)hostBundlePath
//                        device:(SimDevice *)device
//                         error:(NSError **)error;

- (BOOL)installApplicationAndReturnError:(NSError **)error;
- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser andCompletion:(void (^)(NSError *, pid_t pid))completion;

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

@end
