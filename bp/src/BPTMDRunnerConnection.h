//
//  BPTMDRunnerConnection.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BPExecutionContext.h"
#import "BPTMDControlConnection.h"
#import "BPSimulator.h"

// This is the small subset of XCTMessagingChannel_RunnerToIDE protocol that Bluepill implements
@protocol BPTestBundleConnectionDelegate <NSObject>
- (void)_XCT_launchProcessWithPath:(NSString *)path bundleID:(NSString *)bundleID arguments:(NSArray *)arguments environmentVariables:(NSDictionary *)environment;
@end

@interface BPTMDRunnerConnection : NSObject
@property (nonatomic, assign) BOOL disconnected;
@property (nonatomic, strong) BPExecutionContext *context;
@property (nonatomic, strong) BPSimulator *simulator;
@property (nonatomic, copy) void (^completionBlock)(NSError *, pid_t);
- (instancetype)initWithContext:(BPExecutionContext *)context andInterface:(id<BPTestBundleConnectionDelegate>)interface;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
- (void)startTestPlan;
@end

