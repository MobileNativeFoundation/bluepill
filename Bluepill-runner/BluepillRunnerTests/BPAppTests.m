//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPTestHelper.h"
#import "BPConfiguration.h"
#import "BPApp.h"
#import "BPXCTestFile.h"
#import "BPUtils.h"

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
    self.config.runtime = @"iOS 10.1";
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @1;
    self.config.deviceType = @"iPhone 6";}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAppWithAppBundlePathNoError {
    NSError *error;
    NSString *path = self.config.appBundlePath;
    BPApp *app = [BPApp BPAppWithAppBundlePath:path withExtraTestBundles:nil withError:&error];
    XCTAssertNil(error);
    XCTAssertEqual(app.path, self.config.appBundlePath);
    XCTAssert(app.testBundles.count > 2);
}

@end
