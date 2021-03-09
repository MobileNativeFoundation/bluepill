//
//  BPIntegrationTests.m
//  Bluepill
//
//  Created by Yu Li on 1/27/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "bp/tests/BPTestHelper.h"
#import "bp/src/BPConfiguration.h"
#import "bp/src/BPUtils.h"
#import "bluepill/src/BPRunner.h"
#import "bluepill/src/BPApp.h"
#import "bluepill/src/BPPacker.h"
#import "bp/src/BPXCTestFile.h"
#import "bp/src/BPConstants.h"

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
    for (BPXCTestFile *testBundle in app.testBundles) {
        if ([testBundle.name isEqualToString:@"BPSampleAppTests"]) {
            XCTAssertEqual(testBundle.skipTestIdentifiers.count, 8);
        } else {
            XCTAssertEqual(testBundle.skipTestIdentifiers.count, 0);
        }
    }
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
