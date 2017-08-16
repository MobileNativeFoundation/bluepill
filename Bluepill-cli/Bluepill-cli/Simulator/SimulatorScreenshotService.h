//
//  SimulatorScreenshotService.h
//  Bluepill-cli
//
//  Created by Szeremeta Adam on 16.08.2017.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

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
+ (instancetype)simulatorScreenshotServiceWithConfiguration:(BPConfiguration *)config forDevice:(SimDevice *)device;

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
 @return True is save was successfull
 */
- (BOOL)saveScreenshotForFailedTestWithName:(NSString *)name;

@end
