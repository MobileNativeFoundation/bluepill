//
//  BPTestBundleConnection.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCTestManager_IDEInterface-Protocol.h"
#import "SimDevice.h"
#import "BPConfiguration.h"
#import "BPSimulator.h"

@interface BPTestBundleConnection : NSObject
@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) BPSimulator *simulator;
@property (nonatomic, strong) NSString *stdoutPath;
@property (nonatomic, copy) void (^completionBlock)(NSError *, pid_t);
- (instancetype)initWithDevice:(BPSimulator *)device andInterface:(id<XCTestManager_IDEInterface>)interface;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
- (void)startTestPlan;
@end
