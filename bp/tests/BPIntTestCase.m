//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import <XCTest/XCTestAssertions.h>

#import "BPIntTestCase.h"
#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "BPUtils.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "SimServiceContext.h"

@implementation BPIntTestCase

- (void)setUp {
    [super setUp];

    self.continueAfterFailure = NO;
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [[BPConfiguration alloc] initWithProgram:BP_BINARY];
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @40;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.testCaseTimeout = @20;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.headlessMode = YES;
    self.config.videoPaths = @[[BPTestHelper sampleVideoPath]];
    self.config.testRunnerAppPath = nil;
    self.config.testing_CrashAppOnLaunch = NO;
    self.config.cloneSimulator = NO;
    [BPUtils quietMode:[BPUtils isBuildScript]];
    [BPUtils enableDebugOutput:NO];

    NSError *err;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&err];
    if (!sc) { NSLog(@"Failed to initialize SimServiceContext: %@", err); }

    for (SimDeviceType *type in [sc supportedDeviceTypes]) {
        if ([[type name] isEqualToString:self.config.deviceType]) {
            self.config.simDeviceType = type;
            break;
        }
    }

    XCTAssert(self.config.simDeviceType != nil);

    for (SimRuntime *runtime in [sc supportedRuntimes]) {
        if ([[runtime name] containsString:self.config.runtime]) {
            self.config.simRuntime = runtime;
            break;
        }
    }

    XCTAssert(self.config.simRuntime != nil);
}

@end
