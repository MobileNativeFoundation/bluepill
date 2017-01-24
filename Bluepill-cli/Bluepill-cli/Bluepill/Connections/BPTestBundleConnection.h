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

@interface BPTestBundleConnection : NSObject
@property (nonatomic, strong) BPConfiguration *config;
- (instancetype)initWithDevice:(SimDevice *)device andInterface:(id<XCTestManager_IDEInterface>)interface;
- (void)connectWithTimeout:(NSTimeInterval)timeout;
- (void)startTestPlan;
@end
