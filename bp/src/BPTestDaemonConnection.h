//
//  BPTestDaemonConnection.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToRunner-Protocol.h"

// CoreSimulator
#import "BPSimulator.h"

@interface BPTestDaemonConnection : NSObject
@property (nonatomic, assign) pid_t testRunnerPid;
@property (nonatomic, strong) BPSimulator *simulator;
- (instancetype)initWithDevice:(BPSimulator *)device andTestRunnerPID: (pid_t) pid;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
@end
