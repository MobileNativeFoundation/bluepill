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
#import "BPBundle.h"
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
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.failureTolerance = 0;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = NO;
    self.config.junitOutput = NO;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testPacking {
    NSArray *want, *got;
    NSArray *allTests;
    NSArray<BPBundle *> *bundles;

    allTests = [[NSMutableArray alloc] init];
    BPApp *app = [BPApp BPAppWithAppBundlePath:self.config.appBundlePath
                         onlyTestingBundlePath:nil
                          withExtraTestBundles:nil
                                     withError:nil];
    XCTAssert(app != nil);
    // Make sure we have the test bundles we expect. If we add more, this will pop but that's okay. Just add
    // the additional test bundles here.
    want = @[ @"BPAppNegativeTests.xctest",
              @"BPSampleAppCrashingTests.xctest",
              @"BPSampleAppFatalErrorTests.xctest",
              @"BPSampleAppHangingTests.xctest",
              @"BPSampleAppTests.xctest"];
    NSMutableArray *tests = [[NSMutableArray alloc] init];
    for (BPBundle *bundle in app.testBundles) {
        [tests addObject:[bundle.path lastPathComponent]];
    }
    got = [tests sortedArrayUsingSelector:@selector(compare:)];
    XCTAssert([want isEqualToArray:got]);

    // Let's gather all the tests and always make sure we get them all
    tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *testFile in app.testBundles) {
        [tests addObjectsFromArray:[testFile allTestCases]];
    }
    allTests = [tests sortedArrayUsingSelector:@selector(compare:)];
    // Make sure we don't split when we don't want to
    bundles = [BPPacker packTests:app.testBundles testCasesToRun:nil withNoSplitList:@[@"BPSampleAppTests"] intoBundles:4 andError:nil];
    // When we prevent BPSampleTests from splitting, BPSampleAppFatalErrorTests gets split in two
    want = [[want arrayByAddingObject:@"BPSampleAppFatalErrorTests"] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssert(bundles.count == app.testBundles.count + 1);

    XCTAssert([bundles[0].testsToSkip count] == 0);
    XCTAssert([bundles[1].testsToSkip count] == 0);
    XCTAssert([bundles[2].testsToSkip count] == 0);
    XCTAssert([bundles[3].testsToSkip count] == 0);
    XCTAssert([bundles[4].testsToSkip count] == 2);
    XCTAssert([bundles[5].testsToSkip count] == 3);

    bundles = [BPPacker packTests:app.testBundles testCasesToRun:nil withNoSplitList:@[]  intoBundles:4 andError:nil];
    // 4 unbreakable bundles (too few tests) and the big one broken into 4 bundles
    XCTAssert(bundles.count == 8);
    // All we want to test is that we have full coverage
    XCTAssert([bundles[0].testsToSkip count] == 0);
    XCTAssert([bundles[1].testsToSkip count] == 0);
    XCTAssert([bundles[2].testsToSkip count] == 0);
    XCTAssert([bundles[3].testsToSkip count] == 0);
    XCTAssert([bundles[4].testsToSkip count] == 148);
    XCTAssert([bundles[5].testsToSkip count] == 148);
    XCTAssert([bundles[6].testsToSkip count] == 148);
    XCTAssert([bundles[7].testsToSkip count] == 159);

    bundles = [BPPacker packTests:app.testBundles testCasesToRun:nil withNoSplitList:nil intoBundles:1 andError:nil];
    // If we pack into just one bundle, we can't have less bundles than the total number of .xctest files.
    XCTAssert(bundles.count == app.testBundles.count);

    bundles = [BPPacker packTests:app.testBundles testCasesToRun:nil withNoSplitList:nil intoBundles:16 andError:nil];

    XCTAssert([bundles[0].testsToSkip count] == 0);
    XCTAssert([bundles[1].testsToSkip count] == 0);
    XCTAssert([bundles[2].testsToSkip count] == 0);
    XCTAssert([bundles[3].testsToSkip count] == 0);
    XCTAssert([bundles[4].testsToSkip count] == 188);
    XCTAssert([bundles[5].testsToSkip count] == 188);
    XCTAssert([bundles[6].testsToSkip count] == 188);
    XCTAssert([bundles[7].testsToSkip count] == 188);
    XCTAssert([bundles[8].testsToSkip count] == 188);
    XCTAssert([bundles[9].testsToSkip count] == 188);
    XCTAssert([bundles[10].testsToSkip count] == 188);
    XCTAssert([bundles[11].testsToSkip count] == 188);
    XCTAssert([bundles[12].testsToSkip count] == 188);
    XCTAssert([bundles[13].testsToSkip count] == 188);
    XCTAssert([bundles[14].testsToSkip count] == 188);
    XCTAssert([bundles[15].testsToSkip count] == 188);
    XCTAssert([bundles[16].testsToSkip count] == 188);
    XCTAssert([bundles[17].testsToSkip count] == 188);
    XCTAssert([bundles[18].testsToSkip count] == 188);
    XCTAssert([bundles[19].testsToSkip count] == 195);
    
    NSMutableArray *toRun = [[NSMutableArray alloc] init];
    for (long i = 1; i <= 20; i++) {
        [toRun addObject:[NSString stringWithFormat:@"BPSampleAppTests/testCase%03ld", i]];
    }    
    bundles = [BPPacker packTests:app.testBundles testCasesToRun:toRun withNoSplitList:nil intoBundles:4 andError:nil];
    
    XCTAssertEqual(bundles.count, 4);
    for (BPBundle *bundle in bundles) {
        XCTAssertEqual(bundle.testsToSkip.count, 196);
    }
}

- (void)testNoSplittingOfExtraTestBundles {
    // Move the BPSampleAppTests.xctest out of the app so that we get just one.
    NSError *err;
    NSString *inAppBundle = [self.config.appBundlePath stringByAppendingPathComponent:@"Plugins/BPSampleAppTests.xctest"];
    NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"BPSampleAppTests.xctest"];
    if (![[NSFileManager defaultManager] moveItemAtPath:inAppBundle toPath:tmpPath error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(false);
    }
    NSString *additionalXctest = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"BPSampleAppTests.xctest"];
    BOOL isdir;
    XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:additionalXctest isDirectory:&isdir] && isdir);
    self.config.additionalTestBundles = @[additionalXctest];

    BPApp *app = [BPApp BPAppWithAppBundlePath:self.config.appBundlePath
                         onlyTestingBundlePath:nil
                          withExtraTestBundles:self.config.additionalTestBundles
                                     withError:nil];
    XCTAssert(app != nil);

    NSArray *bundles = [BPPacker packTests:app.testBundles testCasesToRun:nil withNoSplitList:@[@"BPSampleAppTests"] intoBundles:4 andError:nil];
    BOOL found = false;
    for (BPBundle *bundle in bundles) {
        if ([[bundle.path lastPathComponent] isEqualToString:@"BPSampleAppTests.xctest"]) {
            XCTAssert(bundle.testsToSkip.count == 0);
            found = true;
        }
    }
    XCTAssert(found);
    // Move the original bundle back to where it was to prevent other tests from failing
    if (![[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:inAppBundle error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(false);
    }
}

@end
