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
#import "BPBundle.h"
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
    self.config.failureTolerance = 0;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = NO;
    self.config.junitOutput = NO;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
    NSLog(@"BPBuildScript = %hhd", [BPUtils isBuildScript]);
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    [BPUtils quietMode:[BPUtils isBuildScript]];
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
    BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:self.config withBpPath:bpPath];
    int rc = [runner run];
    XCTAssert(rc == 0);
    //XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstances {
    self.config.numSims = @2;
    self.config.errorRetriesCount = @2;
    self.config.failureTolerance = 2;
    //self.config.reuseSimulator = NO;

    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:self.config withBpPath:bpPath];
    int rc = [runner run];
    XCTAssert(rc == 0);
    //XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesWithUITests {
    self.config.numSims = @2;
    self.config.errorRetriesCount = @2;
    self.config.failureTolerance = 2;
    //self.config.reuseSimulator = NO;

    self.config.testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    self.config.testRunnerAppPath = [BPTestHelper sampleAppUITestRunnerPath];
    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config
                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:self.config withBpPath:bpPath];
    int rc = [runner run];
    XCTAssert(rc == 0);
    //XCTAssert([runner.nsTaskList count] == 0);
}

- (void)testTwoBPInstancesTestCaseFail {
    self.config.numSims = @2;

    self.config.testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    //self.config.reuseSimulator = NO;

    NSError *err;
    BPApp *app = [BPApp appWithConfig:self.config

                            withError:&err];

    NSString *bpPath = [BPTestHelper bpExecutablePath];
    BPRunner *runner = [BPRunner BPRunnerForApp:app withConfig:self.config withBpPath:bpPath];
    int rc = [runner run];
    XCTAssert(rc != 0);
    //XCTAssert([runner.nsTaskList count] == 0);
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
//    //XCTAssert([runner.nsTaskList count] == 0);
//}

@end
