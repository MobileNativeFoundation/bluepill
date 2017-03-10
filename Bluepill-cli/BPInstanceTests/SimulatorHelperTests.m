//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "SimulatorHelper.h"
#import "BPTestHelper.h"
#import "BPConfiguration.h"
#import "BPUtils.h"

@interface SimulatorHelperTests : XCTestCase
@end

@implementation SimulatorHelperTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];

}

- (void)tearDown {
    [super tearDown];
}

- (void)testAppLaunchEnvironment {
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    BPConfiguration *config = [BPConfiguration new];
    config.testBundlePath = testBundlePath;
    config.appBundlePath = hostApplicationPath;
    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:config.appBundlePath];
    config.xcodePath = @"/Applications/Xcode.app/Contents/Developer";
    NSDictionary *appLaunchEnvironment = [SimulatorHelper appLaunchEnvironmentWithBundleID:hostBundleId device:nil config:config];
    XCTAssert([appLaunchEnvironment[@"AppTargetLocation"] containsString:@"Build/Products/Debug-iphonesimulator/BPSampleApp.app"]);
    XCTAssert([appLaunchEnvironment[@"DYLD_FALLBACK_FRAMEWORK_PATH"] containsString:@"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks"]);
    XCTAssert([appLaunchEnvironment[@"DYLD_FRAMEWORK_PATH"] containsString:@"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks"]);
    XCTAssert([appLaunchEnvironment[@"DYLD_INSERT_LIBRARIES"] containsString:@"Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection"]);
    XCTAssert([appLaunchEnvironment[@"DYLD_LIBRARY_PATH"] containsString:@"/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks"]);
    XCTAssert([appLaunchEnvironment[@"TestBundleLocation"] containsString:@"Build/Products/Debug-iphonesimulator/BPSampleApp.app/Plugins/BPSampleAppTests.xctest"]);
    XCTAssert([appLaunchEnvironment[@"XCInjectBundle"] containsString:@"Build/Products/Debug-iphonesimulator/BPSampleApp.app/Plugins/BPSampleAppTests.xctest"]);
    XCTAssert([appLaunchEnvironment[@"XCInjectBundleInto"] containsString:@"Build/Products/Debug-iphonesimulator/BPSampleApp.app"]);
    XCTAssert([appLaunchEnvironment[@"XCTestConfigurationFilePath"] containsString:@"T/BPSampleAppTests-"]);
}

@end
