//
//  BPTestBundleConnection.h
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BPExecutionContext.h"
#import "BPSimulator.h"

// This is a small subset of XCTestManager_IDEInterface protocol
@protocol BPTestBundleConnectionDelegate <NSObject>
- (void)_XCT_launchProcessWithPath:(NSString *)path bundleID:(NSString *)bundleID arguments:(NSArray *)arguments environmentVariables:(NSDictionary *)environment;
@end

@interface BPTestBundleConnection : NSObject
@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) BPExecutionContext *context;
@property (nonatomic, strong) BPSimulator *simulator;
@property (nonatomic, copy) void (^completionBlock)(NSError *, pid_t);
- (instancetype)initWithContext:(BPExecutionContext *)context andInterface:(id<BPTestBundleConnectionDelegate>)interface;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
- (void)startTestPlan;
@end

