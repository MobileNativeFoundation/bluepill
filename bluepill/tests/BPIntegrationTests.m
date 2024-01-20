//
//  BPIntegrationTests.m
//  Bluepill
//
//  Created by Yu Li on 1/27/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "bluepill/src/BPRunner.h"
#import "bluepill/src/BPApp.h"
#import "bluepill/src/BPPacker.h"

#import <bplib/bplib.h>
#import <bplib/BPTestUtils.h>

@interface BPIntegrationTests : XCTestCase
@end

@implementation BPIntegrationTests

- (BPConfiguration *)generateConfigWithVideoDir:(NSString *)videoDir {
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BLUEPILL_BINARY];
    config.testBundlePath = testBundlePath;
    config.appBundlePath = hostApplicationPath;
    config.stuckTimeout = @80;
    config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    config.runtime = @BP_DEFAULT_RUNTIME;
    config.repeatTestsCount = @1;
    config.errorRetriesCount = @0;
    config.failureTolerance = @0;
    config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    config.headlessMode = YES;
    config.quiet = [BPUtils isBuildScript];
    if (videoDir != nil) {
        config.videosDirectory = videoDir;
        config.keepPassingVideos = true;
    }
    return config;
}

- (BPConfiguration *)generateConfig {
    return [self generateConfigWithVideoDir: nil];
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testArchitecture_x86_64 {
    NSString *bundlePath = BPTestHelper.logicTestBundlePath_x86_64;

    BPConfiguration *config = [BPTestUtils makeUnhostedTestConfiguration];
    config.stuckTimeout = @(2);
    config.testCaseTimeout = @(10);
    // Test multiple test bundles, while skipping any failing tests so that we
    // can still validate that we get a success code..
    config.testBundlePath = bundlePath;

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    NSError *error;
    BPApp *app = [BPApp appWithConfig:config withError:&error];

    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testArchitectureWithSwiftTests_x86_64 {
    NSString *bundlePath = BPTestHelper.logicTestBundlePath_swift_x86_64;

    BPConfiguration *config = [BPTestUtils makeUnhostedTestConfiguration];
    config.stuckTimeout = @(2);
    config.testCaseTimeout = @(10);
    // Test multiple test bundles, while skipping any failing tests so that we
    // can still validate that we get a success code..
    config.testBundlePath = bundlePath;

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    NSError *error;
    BPApp *app = [BPApp appWithConfig:config withError:&error];

    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner busySwimlaneCount] == 0);
}

// Currently having troubles generating a new arm64 fixture.
- (void)DISABLEDtestArchitecture_arm64 {
    NSString *bundlePath = BPTestHelper.logicTestBundlePath_arm64;
    
    BPConfiguration *config = [BPTestUtils makeUnhostedTestConfiguration];
    config.stuckTimeout = @(2);
    config.testCaseTimeout = @(10);
    config.numSims = @(1);
    // Test multiple test bundles, while skipping any failing tests so that we
    // can still validate that we get a success code..
    config.testBundlePath = bundlePath;

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    NSError *error;
    BPApp *app = [BPApp appWithConfig:config withError:&error];

    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testLogicTestBundles {
    BPConfiguration *config = [BPTestUtils makeUnhostedTestConfiguration];
    config.stuckTimeout = @(2);
    config.testCaseTimeout = @(10);
    // Test multiple test bundles, while skipping any failing tests so that we
    // can still validate that we get a success code..
    config.testBundlePath = BPTestHelper.logicTestBundlePath;
    config.additionalUnitTestBundles = @[BPTestHelper.logicTestBundlePath];
    config.testCasesToSkip = @[
        @"BPLogicTests/testFailingLogicTest",
        @"BPLogicTests/testCrashTestCaseLogicTest",
        @"BPLogicTests/testCrashExecutionLogicTest",
        @"BPLogicTests/testStuckLogicTest",
        @"BPLogicTests/testSlowLogicTest",
    ];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    NSError *error;
    BPApp *app = [BPApp appWithConfig:config withError:&error];

    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testTwoBPInstancesWithLogicTestPlanJson {
    [self writeLogicTestPlan];
    BPConfiguration *config = [BPTestUtils makeUnhostedTestConfiguration];
    config.numSims = @2;
    config.testBundlePath = nil;
    config.testRunnerAppPath = nil;
    config.appBundlePath = nil;
    config.testPlanPath = [BPTestHelper testPlanPath];

    NSError *err;
    [config validateConfigWithError:&err];
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc != 0); // this runs tests that fail
    XCTAssertEqual(app.testBundles.count, 2);
    XCTAssertTrue([app.testBundles[0].name isEqualToString:@"BPLogicTests"]);
    XCTAssertEqual(app.testBundles[0].numTests, 10);
    XCTAssertEqual(app.testBundles[0].skipTestIdentifiers.count, 0);
    XCTAssertTrue([app.testBundles[1].name isEqualToString:@"BPPassingLogicTests"]);
    XCTAssertEqual(app.testBundles[1].numTests, 207);
    XCTAssertEqual(app.testBundles[1].skipTestIdentifiers.count, 0);
}

- (void)testOneBPInstance {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @1;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testTwoBPInstances {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner busySwimlaneCount] == 0);
}

// Note: If this is failing for you locally, try resetting all of your
// sims with `sudo rm -rf /private/tmp/com.apple.CoreSimulator.SimDevice.*`
- (void)testClonedSimulators {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    config.cloneSimulator = TRUE;
    // need to validate the configuration to fill in simDevice and simRuntime
    NSError *err = nil;
    [config validateConfigWithError:&err];
    XCTAssert(err == nil);
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testTwoBPInstancesWithUITests {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    // This looks backwards but we want the main app to be the runner
    // and the sampleApp is launched from the callback.
    config.testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    config.testRunnerAppPath = [BPTestHelper sampleAppPath];
    config.appBundlePath = [BPTestHelper sampleAppUITestRunnerPath];

    NSError *err;
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testTwoBPInstancesWithXCTestRunFile {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.testBundlePath = nil;
    config.testRunnerAppPath = nil;
    NSString *baseSDK = [[NSString stringWithUTF8String:BP_DEFAULT_BASE_SDK] stringByReplacingOccurrencesOfString:@"iOS " withString:@""];
    NSString *xcTestRunFile = [NSString stringWithFormat:@"Build/Products/BPSampleApp_iphonesimulator%@-x86_64.xctestrun", baseSDK];
    config.xcTestRunPath = [[[BPTestHelper derivedDataPath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:xcTestRunFile];
    NSError *err;
    [config validateConfigWithError:&err];
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];

    // Set this once we learn how many tests are in the BPSampleAppTests bundle.
    NSInteger sampleAppTestsRemaining = NSNotFound;
    for (BPXCTestFile *testBundle in app.testBundles) {
        // BPSampleAppTests is a huge bundle and will be broken into multiple batches
        // Across all of these batches, the NOT skipped tests should add up to the total
        // test count.
        if ([testBundle.name isEqualToString:@"BPSampleAppTests"]) {
            if (sampleAppTestsRemaining == NSNotFound) {
                sampleAppTestsRemaining = testBundle.allTestCases.count;
            }
            sampleAppTestsRemaining -= (testBundle.allTestCases.count - testBundle.skipTestIdentifiers.count);
        } else {
            XCTAssertEqual(testBundle.skipTestIdentifiers.count, 0);
        }
    }
    XCTAssertEqual(sampleAppTestsRemaining, 0);
    XCTAssert(rc != 0); // this runs tests that fail
}

- (void)testTwoBPInstancesTestCaseFail {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    NSError *err;
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc != 0);
    XCTAssert([runner busySwimlaneCount] == 0);
}

- (void)testTwoBPInstancesWithTestPlanJson {
    [self writeTestPlan];
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.testBundlePath = nil;
    config.testRunnerAppPath = nil;
    config.appBundlePath = nil;
    config.testPlanPath = [BPTestHelper testPlanPath];

    NSError *err;
    [config validateConfigWithError:&err];
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc != 0); // this runs tests that fail
    XCTAssertEqual(app.testBundles.count, 2);
    XCTAssertTrue([app.testBundles[0].name isEqualToString:@"BPAppNegativeTests"]);
    XCTAssertEqual(app.testBundles[0].numTests, 4);
    XCTAssertEqual(app.testBundles[0].skipTestIdentifiers.count, 0);
    XCTAssertTrue([app.testBundles[1].name isEqualToString:@"BPSampleAppTests"]);
    XCTAssertEqual(app.testBundles[1].numTests, 207);
    XCTAssertEqual(app.testBundles[1].skipTestIdentifiers.count, 0);
}

- (void)writeTestPlan {
    NSDictionary *testPlan = @{
        @"tests": @{
            @"BPSampleAppTests": @{
                @"test_host": [BPTestHelper sampleAppPath],
                @"test_host_bundle_identifier": @"identifier",
                @"test_bundle_path": [BPTestHelper sampleAppBalancingTestsBundlePath],
                @"environment": @{},
                @"arguments": @{}
            },
            @"BPAppNegativeTests": @{
                @"test_host": [BPTestHelper sampleAppPath],
                @"test_host_bundle_identifier": @"identifier",
                @"test_bundle_path": [BPTestHelper sampleAppNegativeTestsBundlePath],
                @"environment": @{},
                @"arguments": @{}
            }
        }
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:testPlan options:0 error:nil];
    [jsonData writeToFile:[BPTestHelper testPlanPath] atomically:YES];
}

- (void)writeLogicTestPlan {
    NSDictionary *testPlan = @{
        @"tests": @{
            @"BPLogicTests": @{
                @"test_bundle_path": [BPTestHelper logicTestBundlePath],
                @"environment": @{},
                @"arguments": @{}
            },
            @"BPPassingLogicTests": @{
                @"test_bundle_path": [BPTestHelper passingLogicTestBundlePath],
                @"environment": @{},
                @"arguments": @{}
            }
        }
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:testPlan options:0 error:nil];
    [jsonData writeToFile:[BPTestHelper testPlanPath] atomically:YES];
}

// TODO: Enable this when we figure out issue #469
- (void)DISABLE_testTwoBPInstancesWithVideo {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *mkdtempError;
    NSString *path = [BPUtils mkdtemp:@"bpout" withError:&mkdtempError];
    XCTAssertNil(mkdtempError);

    NSString* videoDirName = @"my_videos";
    NSString *videoPath = [path stringByAppendingPathComponent:videoDirName];
    BPConfiguration *config = [self generateConfigWithVideoDir:videoPath];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    // This looks backwards but we want the main app to be the runner
    // and the sampleApp is launched from the callback.
    config.testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    config.testRunnerAppPath = [BPTestHelper sampleAppPath];
    config.appBundlePath = [BPTestHelper sampleAppUITestRunnerPath];

    NSError *err;
    BPApp *app = [BPApp appWithConfig:config
                            withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];

    // Run the tests through one time to flush out any weird errors that happen with video recording
    BPRunner *dryRunRunner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(dryRunRunner != nil);
    int dryRunRC = [dryRunRunner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(dryRunRC == 0);
    XCTAssert([dryRunRunner busySwimlaneCount] == 0);
    [fileManager removeItemAtPath:videoPath error:nil];
    NSArray *dryRunOutputContents  = [fileManager  contentsOfDirectoryAtPath:videoPath error:nil];
    XCTAssertEqual(dryRunOutputContents.count, 0);

    // Start the real test now
    BPRunner *runner = [BPRunner BPRunnerWithConfig:config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner busySwimlaneCount] == 0);

    NSError *dirContentsError;
    NSArray *directoryContent  = [fileManager contentsOfDirectoryAtPath:videoPath error:&dirContentsError];
    XCTAssertNil(dirContentsError);
    XCTAssertNotNil(directoryContent);
    XCTAssertEqual(directoryContent.count, 2);

    NSString *testClass = @"BPSampleAppUITests";
    NSSet *filenameSet = [NSSet setWithArray: directoryContent];
    XCTAssertEqual(filenameSet.count, 2);
    BOOL hasTest1 = [filenameSet containsObject: [NSString stringWithFormat:@"%@__%@__1.mp4", testClass, @"testExample"]];
    XCTAssertTrue(hasTest1);
    BOOL hasTest2 = [filenameSet containsObject: [NSString stringWithFormat:@"%@__%@__1.mp4", testClass, @"testExample2"]];
    XCTAssertTrue(hasTest2);
}

@end
