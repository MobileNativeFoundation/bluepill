//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "bluepill/src/BPApp.h"
#import "bp/src/BPConfiguration.h"
#import "bp/src/BPXCTestFile.h"
#import "bp/src/BPUtils.h"
#import "bp/src/BPConstants.h"
#import "bp/tests/BPTestHelper.h"

@interface BPAppTests : XCTestCase
@property (nonatomic, strong) BPConfiguration* config;
@end

@implementation BPAppTests

- (void)setUp {
    [super setUp];

    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [BPConfiguration new];
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @20;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @1;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAppWithAppBundlePathNoError {
    NSError *error;
    self.config.testBundlePath = nil;
    self.config.appBundlePath = [BPTestHelper sampleAppPath];
    BPApp *app = [BPApp appWithConfig:self.config withError:&error];
    XCTAssertNil(error);
    XCTAssert(app.testBundles.count > 2);
}

- (void)testAppWithOnlyTestBundlePath {
    NSError *error;
    BPApp *app = [BPApp appWithConfig:self.config withError:&error];
    XCTAssertNil(error);
    XCTAssert(app.testBundles.count == 1);
    BPXCTestFile *testBundle = app.testBundles[0];
    XCTAssertEqualObjects(testBundle.testBundlePath, self.config.testBundlePath);
}

@end
