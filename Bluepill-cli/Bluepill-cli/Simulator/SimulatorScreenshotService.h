//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPConfiguration.h"

@class SimDevice;

/**
 Provides access to screenshots captured for simulator.
 */
@interface SimulatorScreenshotService : NSObject

/**
 Init screenshot service for given config and device.
 Device has to be in either Shutdown or Booted state.

 @param config BPConfiguration
 @param device SimDevice
 @return SimulatorScreenshotService
 */
- (instancetype)initWithConfiguration:(BPConfiguration *)config forDevice:(SimDevice *)device;

#pragma mark Public Methods


/**
 Last screenshot taken from device

 @return CGImageRef
 */
- (CGImageRef)screenshot;

/**
 Save last taken screenshot with given name in failed ui tests screenshots directory.
 If file already exists (another attempt for given test), proper suffix will be added, for example testName_1

 @param name full name for screenshot, usually full failed test name
 */
- (void)saveScreenshotForFailedTestWithName:(NSString *)name;

@end
