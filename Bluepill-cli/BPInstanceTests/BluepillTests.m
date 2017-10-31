//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "Bluepill.h"
#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "SimDeviceType.h"
#import "BPUtils.h"
#import <stdio.h>
#import "BPConstants.h"

/**
 * This test suite is the integration tests to make sure Bluepill instance is working properly
 * - Exit code testing
 * - Report validation
 */
@interface BluepillTests : XCTestCase

@property (nonatomic, strong) BPConfiguration* config;

@end

@implementation BluepillTests

- (void)setUp {
    [super setUp];
    
    self.continueAfterFailure = NO;
    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.testCaseTimeout = @5;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = YES;
    self.config.videoPaths = @[[BPTestHelper sampleVideoPath]];
    self.config.junitOutput = NO;
    self.config.testRunnerAppPath = nil;
    self.config.testing_CrashAppOnLaunch = NO;
    self.config.testing_NoAppWillRun = YES;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
    [BPUtils quietMode:[BPUtils isBuildScript]];

    NSError *err;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&err];
    if (!sc) { NSLog(@"Failed to initialize SimServiceContext: %@", err); }

    for (SimDeviceType *type in [sc supportedDeviceTypes]) {
        if ([[type name] isEqualToString:self.config.deviceType]) {
            self.config.simDeviceType = type;
            break;
        }
    }

    XCTAssert(self.config.simDeviceType != nil);

    for (SimRuntime *runtime in [sc supportedRuntimes]) {
        if ([[runtime name] isEqualToString:self.config.runtime]) {
            self.config.simRuntime = runtime;
            break;
        }
    }

    XCTAssert(self.config.simRuntime != nil);
}

- (void)tearDown {
    [super tearDown];
}

- (void)testAppThatCrashesOnLaunch {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_CrashAppOnLaunch = YES;
    self.config.testing_NoAppWillRun = NO;
    self.config.stuckTimeout = @3;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusSimulatorCrashed, @"Expected: %ld Got: %ld", (long)BPExitStatusAppCrashed, (long)exitCode);

    self.config.testing_NoAppWillRun = YES;
}

- (void)testAppThatHangsOnLaunch {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_HangAppOnLaunch = YES;
    self.config.testing_NoAppWillRun = NO;
    self.config.stuckTimeout = @3;
    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusSimulatorCrashed);

    self.config.testing_NoAppWillRun = YES;
}

- (void)testRecoverSimulatorOnCrash {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/RecoverSimulatorOnCrash", tempDir] withError:nil];
    self.config.outputDirectory = outputDir;

    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_HangAppOnLaunch = YES;
    self.config.testing_NoAppWillRun = NO;
    self.config.stuckTimeout = @3;
    self.config.failureTolerance = @0;
    self.config.errorRetriesCount = @1;
    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusSimulatorCrashed, @"Expected: %ld Got: %ld", (long)BPExitStatusSimulatorCrashed, (long)exitCode);

    self.config.testing_NoAppWillRun = YES;

    NSString *simulator1Path = [outputDir stringByAppendingPathComponent:@"1-simulator.log"];
    NSString *simulator2Path = [outputDir stringByAppendingPathComponent:@"2-simulator.log"];
    NSString *simulator3Path = [outputDir stringByAppendingPathComponent:@"3-simulator.log"];
    NSString *log1 = [NSString stringWithContentsOfFile:simulator1Path encoding:NSUTF8StringEncoding error:nil];
    NSString *log2 = [NSString stringWithContentsOfFile:simulator2Path encoding:NSUTF8StringEncoding error:nil];
    NSString *log3 = [NSString stringWithContentsOfFile:simulator3Path encoding:NSUTF8StringEncoding error:nil];
    XCTAssert(log1 != nil);
    XCTAssert(log2 != nil);
    XCTAssert(log3 == nil);
}

- (void)testRunningOnlyCertainTestcases {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppPassingTests", tempDir] withError:nil];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = NO;
    self.config.plainOutput = YES;
    self.config.errorRetriesCount = @2;
    self.config.testCasesToRun = @[
                                   @"BPSampleAppTests/testCase173",
                                   @"BPSampleAppTests/testCase199"
                                   ];

    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);

    NSString *textReportPath = [outputDir stringByAppendingPathComponent:@"1-BPSampleAppTests-results.txt"];
    NSString *contents = [NSString stringWithContentsOfFile:textReportPath encoding:NSUTF8StringEncoding error:nil];
    // We'll go line by line asserting we didn't run any extra testcases.
    NSArray *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    int found = 0;
    for (NSString *line in lines) {
        if ([line rangeOfString:@"testCase"].location == NSNotFound) continue;
        XCTAssert([line containsString:@"testCase173"] || [line containsString:@"testCase199"]);
        if ([line containsString:@"testCase173"]) found++;
        if ([line containsString:@"testCase199"]) found++;
    }
    XCTAssert(found == 2); // We must have found both testcases
}

- (void)testRunningAndIgnoringCertainTestCases {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppPassingTests", tempDir] withError:nil];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = NO;
    self.config.plainOutput = YES;
    self.config.errorRetriesCount = @2;
    self.config.testCasesToRun = @[
                                   @"BPSampleAppTests/testCase173",
                                   @"BPSampleAppTests/testCase199"
                                   ];
    
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase173"];
    
    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
    
    NSString *textReportPath = [outputDir stringByAppendingPathComponent:@"1-BPSampleAppTests-results.txt"];
    NSString *contents = [NSString stringWithContentsOfFile:textReportPath encoding:NSUTF8StringEncoding error:nil];
    // We'll go line by line asserting we didn't run any extra testcases.
    NSArray *lines = [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    int found = 0;
    for (NSString *line in lines) {
        if ([line rangeOfString:@"testCase"].location == NSNotFound) continue;
        XCTAssert([line containsString:@"testCase199"]);
        if ([line containsString:@"testCase199"]) found++;
    }
    XCTAssert(found == 1); // We must have found both testcases
}

- (void)testReportWithAppCrashingTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppCrashingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;
    self.config.errorRetriesCount = @1;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);
    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPSampleAppCrashingTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
}

- (void)testReportWithAppCrashingAndRetryOnlyFailedTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppCrashingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;
    self.config.errorRetriesCount = @1;
    self.config.failureTolerance = @1;
    self.config.onlyRetryFailed = YES;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPSampleAppCrashingTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
}

- (void)testReportWithFatalErrorTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppFatalTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppFatalErrorTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;
    self.config.errorRetriesCount = @5;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    // BUG: Sometimes the app crashes instead of timing out
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed || exitCode == BPExitStatusAppCrashed);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPSampleAppFatalErrorTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"fatal_tests.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
}

- (void)testReportWithAppHangingTestsSet {
    self.config.stuckTimeout = @3;
    self.config.plainOutput = YES;
    self.config.errorRetriesCount = @4;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    // BUG: Sometimes the app crashes instead of timing out
    XCTAssertTrue(exitCode == BPExitStatusTestTimeout || exitCode == BPExitStatusAppCrashed);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPSampleAppHangingTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"hanging_tests.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
}

/**
 The scenario is:
 - if a test timeout or crashed, even if we proceed to the next test, we should still return error exit code.
 */
- (void)testReportWithAppHangingTestsShouldReturnFailure {
    self.config.stuckTimeout = @3;
    self.config.plainOutput = YES;
    self.config.failureTolerance = @0;
    self.config.errorRetriesCount = @4;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    // BUG: Sometimes the app crashes instead of timing out
    XCTAssertTrue(exitCode == BPExitStatusTestTimeout || exitCode == BPExitStatusAppCrashed);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPSampleAppHangingTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"hanging_tests.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
}

- (void)testReportWithFailingTestsSetAndDiagnostics {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;
    self.config.saveDiagnosticsOnError = YES;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPAppNegativeTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"BPAppNegativeTests-results.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];
    NSFileManager *fm = [NSFileManager defaultManager];
    [BPUtils runShell:[NSString stringWithFormat:@"find %@", outputDir]];
    BOOL diagFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/diagnostics.tar.gz", outputDir]];
    XCTAssert(diagFileFound);
    BOOL psFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/ps-axuw.log", outputDir]];
    XCTAssert(psFileFound);
    BOOL dfFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/df-h.log", outputDir]];
    XCTAssert(dfFileFound);
    XCTAssert(exitCode == BPExitStatusTestsFailed);
}

- (void)testRetryWithFailingTestsSet {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @100;
    self.config.junitOutput = YES;
    self.config.failureTolerance = @1;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);
    // validate the report
    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"BPAppNegativeTests-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"failure_retry_report.xml"];
    [self compareReportAtPath:junitReportPath withReportAtPath:expectedFilePath];

}

- (void)testRetryWithFailingTestsRetriesAll {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @100;
    self.config.junitOutput = YES;
    self.config.failureTolerance = @1;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);
    // Make sure all tests started on the first run
    NSString *simulator1Path = [outputDir stringByAppendingPathComponent:@"1-simulator.log"];
    NSString *log1 = [NSString stringWithContentsOfFile:simulator1Path encoding:NSUTF8StringEncoding error:nil];
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertFailure]' started."].location != NSNotFound);
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertTrue]' started."].location != NSNotFound);
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testRaiseException]' started."].location != NSNotFound);
    // Make sure all tests started on the second run (because `onlyRetryFailed` defaults to NO)
    NSString *simulator2Path = [outputDir stringByAppendingPathComponent:@"2-simulator.log"];
    NSString *log2 = [NSString stringWithContentsOfFile:simulator2Path encoding:NSUTF8StringEncoding error:nil];
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertFailure]' started."].location != NSNotFound);
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertTrue]' started."].location != NSNotFound);
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testRaiseException]' started."].location != NSNotFound);
}

- (void)testRetryOnlyFailures {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @100;
    self.config.junitOutput = YES;
    self.config.failureTolerance = @1;
    self.config.onlyRetryFailed = YES;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);
    // Make sure all tests started on the first run
    NSString *simulator1Path = [outputDir stringByAppendingPathComponent:@"1-simulator.log"];
    NSString *log1 = [NSString stringWithContentsOfFile:simulator1Path encoding:NSUTF8StringEncoding error:nil];
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertFailure]' started."].location != NSNotFound);
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertTrue]' started."].location != NSNotFound);
    XCTAssert([log1 rangeOfString:@"Test Case '-[BPAppNegativeTests testRaiseException]' started."].location != NSNotFound);
    // Make sure only failing tests started on the second run
    NSString *simulator2Path = [outputDir stringByAppendingPathComponent:@"2-simulator.log"];
    NSString *log2 = [NSString stringWithContentsOfFile:simulator2Path encoding:NSUTF8StringEncoding error:nil];
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertFailure]' started."].location != NSNotFound);
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testAssertTrue]' started."].location == NSNotFound);
    XCTAssert([log2 rangeOfString:@"Test Case '-[BPAppNegativeTests testRaiseException]' started."].location != NSNotFound);
}

// Top level test for Bluepill instance
- (void)testRunWithPassingTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase000"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
}

- (void)testReuseSimulator {
    //[BPUtils quietMode:NO];
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);
    
    self.config.useSimUDID = bp.test_simulatorUDID;
    XCTAssertNotNil(self.config.useSimUDID);
    
    NSString *oldDeviceID = self.config.useSimUDID;
    self.config.keepSimulator = NO;
    
    Bluepill *bp2 = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp2 run];
    XCTAssert(exitCode2 == BPExitStatusTestsAllPassed);

    XCTAssertNotNil(bp2.test_simulatorUDID);
    XCTAssertEqualObjects(oldDeviceID, bp2.test_simulatorUDID);

}

- (void)testReuseSimulatorRetryAppCrashingTestsSet  {
    //[BPUtils quietMode:NO];
    
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);
    
    self.config.useSimUDID = bp.test_simulatorUDID;
    XCTAssertNotNil(self.config.useSimUDID);
    
    NSString *oldDeviceID = self.config.useSimUDID;
    
    self.config.testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.failureTolerance = @1;
    self.config.keepSimulator = NO;
    self.config.errorRetriesCount = @2;
    
    Bluepill *bp2 = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp2 run];
    XCTAssert(exitCode2 == BPExitStatusAppCrashed);

    XCTAssertNotNil(bp2.test_simulatorUDID);
    //Specified device has been deleted due to crashed test case and a NEW sim sould be created when RETRY
    XCTAssertNotEqualObjects(oldDeviceID, bp2.test_simulatorUDID);
}

- (void)testReuseSimulatorNotExist {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.useSimUDID = @"XXXXX";
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusSimulatorCreationFailed);
    XCTAssertNil(bp.test_simulatorUDID);
}

- (void)testReuseSimulatorNotExistWithRetry {
    //[BPUtils quietMode:NO];
    NSString *badDeviceID = @"XXXXX";
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.useSimUDID = badDeviceID;
    self.config.failureTolerance = @1;
    self.config.errorRetriesCount = @2;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);
    XCTAssertNotEqual(badDeviceID, bp.test_simulatorUDID);
}

//simulator shouldn't be kept in this case
- (void)testKeepSimulatorWithAppCrashingTestsSet  {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusAppCrashed);

}

//simulator shouldn't be kept in this case
- (void)testKeepSimulatorWithAppHaningTestsSet  {
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusTestTimeout);

}

- (void)testDeleteSimulatorOnly {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    
    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);
    
    self.config.deleteSimUDID = bp.test_simulatorUDID;
    XCTAssertNotNil(self.config.deleteSimUDID);
    
    Bluepill *bp2 = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp2 run];
    XCTAssert(exitCode2 == BPExitStatusSimulatorDeleted);
    XCTAssertEqualObjects(self.config.deleteSimUDID, bp2.test_simulatorUDID);

}

//make sure we don't retry to create a new simulator to delete
- (void)testDeleteSimulatorNotExistWithRetry {
    self.config.failureTolerance = @1;
    self.config.errorRetriesCount = @2;
    self.config.deleteSimUDID = @"XXXXX";

    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp run];
    XCTAssert(exitCode2 == BPExitStatusSimulatorReuseFailed);
    XCTAssertNil(bp.test_simulatorUDID);
}

- (void)testRunUITest {
    // The delay of ui test bootstrapping is larger than 5s.
    self.config.testCaseTimeout = @300;
    NSString *testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    NSString *testRunnerPath = [BPTestHelper sampleAppUITestRunnerPath];
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/UITestsSetTempDir", tempDir] withError:&error];
    self.config.testRunnerAppPath = testRunnerPath;
    self.config.testBundlePath = testBundlePath;
    self.config.outputDirectory = outputDir;
    self.config.junitOutput = YES;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    self.config.testRunnerAppPath = nil;
    XCTAssert(exitCode == BPExitStatusTestsAllPassed);
}

- (void)testTakingScreenshotWithFailingTestsSet {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.screenshotsDirectory = outputDir;

    NSArray *expectedScreenshotsFileNames = @[@"BPAppNegativeTests_testAssertFailure_attempt_1.jpeg",
                                              @"BPAppNegativeTests_testRaiseException_attempt_1.jpeg"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);

    for (NSString *filename in expectedScreenshotsFileNames) {
        NSString *filePath = [outputDir stringByAppendingPathComponent:filename];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        XCTAssert(fileExists);
    }
}

- (void)testTakingScreenshotWithFailingTestsSetWithRetries {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.screenshotsDirectory = outputDir;
    self.config.failureTolerance = @(1);

    NSArray *expectedScreenshotsFileNames = @[@"BPAppNegativeTests_testAssertFailure_attempt_1.jpeg",
                                              @"BPAppNegativeTests_testAssertFailure_attempt_2.jpeg",
                                              @"BPAppNegativeTests_testRaiseException_attempt_1.jpeg",
                                              @"BPAppNegativeTests_testRaiseException_attempt_2.jpeg"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);

    for (NSString *filename in expectedScreenshotsFileNames) {
        NSString *filePath = [outputDir stringByAppendingPathComponent:filename];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        XCTAssert(fileExists);
    }
}

- (void)testThatScreenshotAreNotTakenWithFailingTestsSetWithoutConfigOption {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;

    NSArray *expectedScreenshotsFileNames = @[@"BPAppNegativeTests_testAssertFailure_attempt_1.jpeg",
                                              @"BPAppNegativeTests_testRaiseException_attempt_1.jpeg"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusTestsFailed);

    for (NSString *filename in expectedScreenshotsFileNames) {
        NSString *filePath = [outputDir stringByAppendingPathComponent:filename];
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
        XCTAssertFalse(fileExists);
    }
}

#pragma mark - Test helpers

- (void)compareReportAtPath:(NSString *)first withReportAtPath:(NSString *)second {
    NSURL *reportUrl = [NSURL fileURLWithPath:first];
    NSURL *expectedReportUrl = [NSURL fileURLWithPath:second];
    NSXMLDocument *reportXML = [[NSXMLDocument alloc] initWithContentsOfURL:reportUrl options:0 error:nil];
    NSXMLDocument *expectedReportXML = [[NSXMLDocument alloc] initWithContentsOfURL:expectedReportUrl options:0 error:nil];
    [self compareElement:[reportXML nodesForXPath:@".//testsuites" error:nil][0] withElement:[expectedReportXML nodesForXPath:@".//testsuites" error:nil][0]];
}
- (void)compareElement:(NSXMLElement *)first withElement:(NSXMLElement *)second {
    if ([first name] == nil) {
        return;
    }
    XCTAssertTrue([[first name] isEqualToString:[second name]]);
    if ([[first name] isEqualToString:@"testsuite"] || [[first name] isEqualToString:@"testsuites"]) {
        XCTAssertEqual([first attributeForName:@"tests"], [first attributeForName:@"tests"]);
        XCTAssertEqual([first attributeForName:@"failures"], [first attributeForName:@"failures"]);
        XCTAssertEqual([first attributeForName:@"errors"], [first attributeForName:@"errors"]);
        XCTAssertEqual([first attributeForName:@"name"], [first attributeForName:@"name"]);
    }
    if ([[first name] isEqualToString:@"failure"]) {
        XCTAssertEqual([first attributeForName:@"message"], [first attributeForName:@"message"]);
    }
    NSArray *firstNodeChildren = [first children];
    NSArray *secondNodeChildren = [second children];
    XCTAssert([firstNodeChildren count] == [secondNodeChildren count]);
    for (int i = 0; i < [firstNodeChildren count]; i++) {
        [self compareElement:firstNodeChildren[i] withElement:secondNodeChildren[i]];
    }

}

@end
