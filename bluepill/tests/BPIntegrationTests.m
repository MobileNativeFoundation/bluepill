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

- (BPConfiguration *)generateConfig {
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
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
    return config;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @80;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.failureTolerance = @0;
    self.config.headlessMode = YES;
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    [BPUtils quietMode:[BPUtils isBuildScript]];
    self.config.quiet = [BPUtils isBuildScript];
    [self.config validateConfigWithError:nil];
    // Fill in simDeviceType and simRuntime with defaults
    [self.config fillSimDeviceTypeAndRuntimeWithError:nil];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOneBPInstance {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @1;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstances {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testCloneSimulatorConfig {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.errorRetriesCount = @1;
    config.failureTolerance = @0;
    config.cloneSimulator = TRUE;
    // need to validate the configuration to fill in simDevice and simRuntime
    [config validateConfigWithError:nil];
    NSError *err;
    BPRunner *runner;
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert([runner.testHostSimTemplates count] > 0);
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
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
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesWithXCTestRunFile {
    BPConfiguration *config = [self generateConfig];
    config.numSims = @2;
    config.testBundlePath = nil;
    config.testRunnerAppPath = nil;
    NSString *runtime = [[NSString stringWithUTF8String:BP_DEFAULT_RUNTIME] stringByReplacingOccurrencesOfString:@"iOS " withString:@""];
    NSString *xcTestRunFile = [NSString stringWithFormat:@"Build/Products/BPSampleApp_iphonesimulator%@-x86_64.xctestrun", runtime];
    config.xcTestRunPath = [[[BPTestHelper derivedDataPath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:xcTestRunFile];
    NSError *err;
    [config validateConfigWithError:&err];
    XCTAssertNil(err);
    [config fillSimDeviceTypeAndRuntimeWithError:&err];
    XCTAssertNil(err);
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
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
    BPApp *app = [BPApp appWithConfig:config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    XCTAssert(runner != nil);
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc != 0);
    XCTAssert([runner.nsTaskList count] == 0);
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

@end
