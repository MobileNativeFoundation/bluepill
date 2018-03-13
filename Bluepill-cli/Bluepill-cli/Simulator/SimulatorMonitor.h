//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPExecutionPhaseProtocol.h"
#import "BPExitStatus.h"
#import "SimulatorScreenshotService.h"

typedef NS_ENUM(NSInteger, State) {
    Idle,
    Running,
    Completed
};

@class SimDevice;
@class BPConfiguration;

@interface SimulatorMonitor : NSObject<BPExecutionPhaseProtocol, BPExitStatusProtocol>

@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) NSString *hostBundleId;
@property (nonatomic, assign) State appState;
@property (nonatomic, assign) State parserState;
@property (nonatomic, assign) State testsState;
@property (nonatomic, strong) SimulatorScreenshotService *screenshotService;
@property (nonatomic) pid_t appPID;

/*!
 * @discussion Sets timeouts for max test runtime
 */
@property (nonatomic, assign) NSTimeInterval maxTimeWithNoOutput;

/*!
 * @discussion Sets timeouts for max time with no output from the simulator
 */
@property (nonatomic, assign) NSTimeInterval maxTestExecutionTime;

+ (SimulatorMonitor*)sharedInstanceWithConfig:(BPConfiguration *)config;
- (instancetype)initWithConfiguration:(BPConfiguration *)config;
- (void)onOutputReceived;
- (void)onAppEnded;

@end
