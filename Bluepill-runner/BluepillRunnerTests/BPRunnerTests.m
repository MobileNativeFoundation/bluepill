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
#import "BPUtils.h"
#import "BPRunner.h"
#import "BPApp.h"
#import "BPPacker.h"
#import "BPXCTestFile.h"
#import "BPConstants.h"

@interface BPRunnerTests : XCTestCase
@property (nonatomic, strong) BPConfiguration* config;
@end

@implementation BPRunnerTests

- (void)setUp {
    [super setUp];
    
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [BPConfiguration new];
    self.config.program = BP_MASTER;
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @2;
    self.config.failureTolerance = @1;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = NO;
    self.config.junitOutput = NO;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
}

- (void)tearDown {
    self.config.testCasesToSkip = @[];
    [super tearDown];
}

- (void)testNoSplittingOfExtraTestBundles {
    // Move the BPSampleAppTests.xctest out of the app so that we get just one.
    NSError *err;
    NSString *inAppBundle = [self.config.appBundlePath stringByAppendingPathComponent:@"PlugIns/BPSampleAppTests.xctest"];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"BPSampleAppTests.xctest"];
    if (![[NSFileManager defaultManager] moveItemAtPath:inAppBundle toPath:tmpPath error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(false);
    }
    NSString *additionalXctest = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"BPSampleAppTests.xctest"];
    BOOL isdir;
    XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:additionalXctest isDirectory:&isdir] && isdir);
    self.config.additionalUnitTestBundles = @[additionalXctest];

    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);

    self.config.numSims = @4;
    self.config.noSplit = @[@"BPSampleAppTests"];
    NSArray *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];

    BOOL found = false;
    for (BPXCTestFile *bundle in bundles) {
        if ([[bundle.testBundlePath lastPathComponent] isEqualToString:@"BPSampleAppTests.xctest"]) {
            XCTAssert(bundle.skipTestIdentifiers.count == 0);
            found = true;
        }
    }
    XCTAssert(found);
    // Move the original bundle back to where it was to prevent other tests from failing
    if (![[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:inAppBundle error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(false);
    }
    XCTAssert(false);
}

@end
