//
//  BPTestUtils.m
//  bp-tests
//
//  Created by Lucas Throckmorton on 2/17/23.
//  Copyright © 2023 LinkedIn. All rights reserved.
//

#import "BPTestUtils.h"

#import <XCTest/XCTest.h>

#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "BPUtils.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "SimServiceContext.h"

@implementation BPTestUtils

+ (nonnull BPConfiguration *)makeUnhostedTestConfiguration {
    BPConfiguration *config = [self makeDefaultTestConfiguration];
    config.isLogicTestTarget = YES;
    return config;
}

+ (nonnull BPConfiguration *)makeHostedTestConfiguration {
    BPConfiguration *config = [self makeDefaultTestConfiguration];

    // Set up simulator device + runtime
    NSError *err;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:config.xcodePath error:&err];
    if (!sc) { NSLog(@"Failed to initialize SimServiceContext: %@", err); }

    for (SimDeviceType *type in [sc supportedDeviceTypes]) {
        if ([[type name] isEqualToString:config.deviceType]) {
            config.simDeviceType = type;
            break;
        }
    }
    XCTAssert(config.simDeviceType != nil);

    for (SimRuntime *runtime in [sc supportedRuntimes]) {
        if ([[runtime name] containsString:config.runtime]) {
            config.simRuntime = runtime;
            break;
        }
    }
    XCTAssert(config.simRuntime != nil);

    NSString *hostApplicationPath =  [BPTestHelper sampleAppPath];
    NSString *testBundlePath =  [BPTestHelper sampleAppNegativeTestsBundlePath];
    config.isLogicTestTarget = NO;
    config.appBundlePath = hostApplicationPath;
    config.testBundlePath = testBundlePath;

    return config;
}

+ (nonnull BPConfiguration *)makeDefaultTestConfiguration {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_BINARY];
    config.stuckTimeout = @40;
    config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    config.runtime = @BP_DEFAULT_RUNTIME;
    config.repeatTestsCount = @1;
    config.errorRetriesCount = @0;
    config.testCaseTimeout = @20;
    config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    config.headlessMode = YES;
    config.videoPaths = @[[BPTestHelper sampleVideoPath]];
    config.testRunnerAppPath = nil;
    config.testing_CrashAppOnLaunch = NO;
    config.cloneSimulator = NO;
    config.outputDirectory = @"/Users/lthrockm/Desktop/output/";
    return config;
}

@end
