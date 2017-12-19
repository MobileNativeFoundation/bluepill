//
//  BPIntegrationTests.m
//  Bluepill
//
//  Created by Yu Li on 1/27/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BPTestHelper.h"
#import "BPConfiguration.h"
#import "BPUtils.h"
#import "BPRunner.h"
#import "BPApp.h"
#import "BPPacker.h"
#import "BPXCTestFile.h"
#import "BPConstants.h"

@interface BPIntegrationTests : XCTestCase
@property (nonatomic, strong) BPConfiguration* config;
@end

@implementation BPIntegrationTests

- (void)setUp {
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.failureTolerance = @0;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = YES;
    self.config.junitOutput = NO;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    [BPUtils quietMode:[BPUtils isBuildScript]];
    self.config.quiet = [BPUtils isBuildScript];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOneBPInstance {
    self.config.numSims = @1;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0, @"Wanted 0, got %d", rc);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstances {
    self.config.numSims = @2;
    self.config.errorRetriesCount = @1;
    self.config.failureTolerance = @0;
    self.config.reuseSimulator = NO;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesWithUITests {
    self.config.numSims = @2;
    self.config.errorRetriesCount = @1;
    self.config.failureTolerance = @0;
    self.config.reuseSimulator = NO;
    // This looks backwards but we want the main app to be the runner
    // and the sampleApp is launched from the callback.
    self.config.testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    self.config.testRunnerAppPath = [BPTestHelper sampleAppPath];
    self.config.appBundlePath = [BPTestHelper sampleAppUITestRunnerPath];


    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesWithXCTestRunFile {
    self.config.numSims = @2;
    self.config.testBundlePath = nil;
    self.config.testRunnerAppPath = nil;
    NSString *runtime = [[NSString stringWithUTF8String:BP_DEFAULT_RUNTIME] stringByReplacingOccurrencesOfString:@"iOS " withString:@""];
    NSString *xcTestRunFile = [NSString stringWithFormat:@"BPSampleApp_iphonesimulator%@-x86_64.xctestrun", runtime];
    self.config.xcTestRunPath = [[[BPTestHelper derivedDataPath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:xcTestRunFile];
    NSError *err;
    [self.config validateConfigWithError:&err];
    BPApp *app = [BPApp appWithConfig:self.config withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(app.testBundles[1].skipTestIdentifiers.count == 7);
    XCTAssert(rc != 0); // this runs tests that fail
}

- (void)testTwoBPInstancesTestCaseFail {
    self.config.numSims = @2;
    self.config.testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config.reuseSimulator = NO;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];
    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc != 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesReuseSim {
    self.config.numSims = @2;
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    [BPUtils quietMode:[BPUtils isBuildScript]];
    self.config.reuseSimulator = YES;
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerWithConfig:self.config withBpPath:bpPath];
    int rc = [runner runWithBPXCTestFiles:app.testBundles];
    XCTAssert(rc == 0);
    XCTAssert([runner.nsTaskList count] == 0);
}

// This test killed Travis, have to disable it.
//- (void)testFourBPInstances {
//    self.config.numSims = @4;
//    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
//    [BPUtils quietMode:[BPUtils isBuildScript]];
//    //self.config.reuseSimulator = YES;
//
//    NSError *err;
//    BPApp *app = [BPApp appWithConfig:self.config
//                            withError:&err];
//
//    NSString *bpPath = [BPTestHelper bpExecutablePath];
//    BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:self.config withBpPath:bpPath];
//    int rc = [runner run];
//    XCTAssert(rc == 0);
//    XCTAssert([runner.nsTaskList count] == 0);
//}

@end
