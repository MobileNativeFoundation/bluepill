//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

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
    config.testBundlePath = [BPTestHelper logicTestBundlePath];
    config.isLogicTestTarget = YES;
    return config;
}

+ (nonnull BPConfiguration *)makeHostedTestConfiguration {
    BPConfiguration *config = [self makeDefaultTestConfiguration];
    config.appBundlePath = [BPTestHelper sampleAppPath];
    config.testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    config.isLogicTestTarget = NO;
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

    return config;
}

+ (void)assertExitStatus:(BPExitStatus)exitStatus matchesExpected:(BPExitStatus)expectedStatus {
    XCTAssert(exitStatus == expectedStatus,
              @"Expected: %@ Got: %@",
              [BPExitStatusHelper stringFromExitStatus:expectedStatus],
              [BPExitStatusHelper stringFromExitStatus:exitStatus]);
}

+ (BOOL)isTestSwiftTest:(NSString *)testName {
    return [testName containsString:@"."] || [testName containsString:@"()"];
}

+ (NSString *)formatSwiftTestForXCTest:(NSString *)testName withBundleName:(NSString *)bundleName {
    NSString *formattedName = testName;
    // Remove parentheses
    NSRange range = [formattedName rangeOfString:@"()"];
    if (range.location != NSNotFound) {
        formattedName = [formattedName substringToIndex:range.location];
    }
    // Add `<bundleName>.`
    NSString *bundlePrefix = [bundleName stringByAppendingString:@"."];
    if (![formattedName containsString:bundlePrefix]) {
        formattedName = [NSString stringWithFormat:@"%@.%@", bundleName, formattedName];
    }
    return formattedName;
}

+ (BOOL)checkIfTestCase:(NSString *)testCase bundleName:(NSString *)bundleName wasRunInLog:(NSString *)logPath {
    NSString *testName = testCase;
    if ([self isTestSwiftTest:testName]) {
        testName = [BPUtils formatSwiftTestForXCTest:testName withBundleName:bundleName];
    }
    NSArray *testComponents = [testName componentsSeparatedByString:@"/"];
    NSString *expectedString = [NSString stringWithFormat:@"Test Case '-[%@ %@]' started.", testComponents[0], testComponents[1]];
    NSString *log = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    XCTAssertNotNil(log);
    NSLog(@"log: %@", log);
    return [log rangeOfString:expectedString].location != NSNotFound;
}

@end
