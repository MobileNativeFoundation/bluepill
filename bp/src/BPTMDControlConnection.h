//
//  BPTMDControlConnection.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToRunner-Protocol.h"
#import "PrivateHeaders/DTXConnectionServices/DTXConnection.h"
#import "PrivateHeaders/CoreSimulator/SimDevice.h"


// CoreSimulator
#import "BPSimulator.h"

DTXConnection *connectToTestManager(SimDevice *device);

@interface BPTMDControlConnection : NSObject
@property (nonatomic, assign) pid_t testRunnerPid;
@property (nonatomic, strong) SimDevice *device;
- (instancetype)initWithSimDevice:(SimDevice *)device andTestRunnerPID: (pid_t) pid;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
@end
