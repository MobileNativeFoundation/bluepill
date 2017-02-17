//
//  BPSimulator.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/16/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BPExitStatus.h"

@class BPConfiguration;
@class BPTreeParser;
@class SimDevice;

@interface BPSimulator : NSObject

@property (nonatomic, assign, readonly) BOOL needsRetry;
@property (nonatomic, readonly) NSString *UDID;
@property (nonatomic, strong) SimDevice *device;

+ (instancetype)simulatorWithConfiguration:(BPConfiguration *)config;

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion;

- (void)bootWithCompletion:(void (^)(NSError *error))completion;

- (void)openSimulatorWithCompletion:(void (^)(NSError *))completion;

- (BOOL)installApplicationAndReturnError:(NSError *__autoreleasing *)error;

- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser andCompletion:(void (^)(NSError *, pid_t))completion isHostApp:(BOOL)isHostApp;

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

@end
