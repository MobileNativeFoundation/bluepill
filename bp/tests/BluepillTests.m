//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import <XCTest/XCTestAssertions.h>

#import "Bluepill.h"
#import "BPIntTestCase.h"
#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "BPUtils.h"
#import "BPSimulator.h"

#import "SimDevice.h"

/**
 * This test suite is the integration tests to make sure Bluepill instance is working properly
 * - Exit code testing
 * - Report validation
 */
@interface BluepillTests : BPIntTestCase
@end

@implementation BluepillTests



- (void)tearDown {
    [super tearDown];
}

- (void)testAppThatCrashesOnLaunch {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_CrashAppOnLaunch = YES;
    self.config.stuckTimeout = @3;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusAppCrashed,
              @"Expected: %@ Got: %@",
              [BPExitStatusHelper stringFromExitStatus:BPExitStatusAppCrashed],
              [BPExitStatusHelper stringFromExitStatus:exitCode]);
}

- (void)testAppThatHangsOnLaunch {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_HangAppOnLaunch = YES;
    self.config.stuckTimeout = @3;
    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusSimulatorCrashed,
              @"Expected: %@ Got: %@",
              [BPExitStatusHelper stringFromExitStatus:BPExitStatusSimulatorCrashed],
              [BPExitStatusHelper stringFromExitStatus:exitCode]);
}

- (void)testRecoverSimulatorOnCrash {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/RecoverSimulatorOnCrash", tempDir] withError:nil];
    self.config.outputDirectory = outputDir;

    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.testing_HangAppOnLaunch = YES;
    self.config.stuckTimeout = @3;
    self.config.failureTolerance = @0;
    self.config.errorRetriesCount = @1;
    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusSimulatorCrashed, @"Expected: %ld Got: %ld", (long)BPExitStatusSimulatorCrashed, (long)exitCode);

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
    self.config.errorRetriesCount = @2;
    self.config.testCasesToRun = @[
                                   @"BPSampleAppTests/testCase173",
                                   @"BPSampleAppTests/testCase199"
                                   ];

    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);

    NSString *reportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppTests-1-results.xml"];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:reportPath] options:0 error:&error];
    XCTAssert(doc, @"Could not find report in '%@': %@", self.config.outputDirectory, [error localizedDescription]);
    for (NSString *testCase in self.config.testCasesToRun) {
        NSArray *parts = [testCase componentsSeparatedByString:@"/"];
        XCTAssert(parts[1]);
        NSXMLElement *element = [[doc nodesForXPath:[NSString stringWithFormat:@"//testcase[@name='%@']", parts[1]] error:nil] firstObject];
        XCTAssert(element, @"%@ not found in report", parts[1]);
    }
}

- (void)testRunningAndIgnoringCertainTestCases {
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppPassingTests", tempDir] withError:nil];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @2;
    self.config.testCasesToRun = @[
                                   @"BPSampleAppTests/testCase173",
                                   @"BPSampleAppTests/testCase199"
                                   ];

    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase173"];

    BPExitStatus exitCode = [[[Bluepill alloc] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);

    NSString *reportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppTests-1-results.xml"];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:reportPath] options:0 error:&error];
    XCTAssert(doc, @"Could not find report in '%@': %@", self.config.outputDirectory, [error localizedDescription]);
    NSString *name = @"testCase199";
    NSXMLElement *element = [[doc nodesForXPath:[NSString stringWithFormat:@"//testcase[@name='%@']", name] error:nil] firstObject];
    XCTAssert(element, @"%@ not found in report", name);
    name = @"testCase173";
    element = [[doc nodesForXPath:[NSString stringWithFormat:@"//testcase[@name='%@']", name] error:nil] firstObject];
    XCTAssert(element == nil, @"%@ found in report, should be skipped", name);
}

/**
 Execution plan: CRASH
 */
- (void)testNoRetryOnCrash {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"CRASH";  // No retry
    self.config.errorRetriesCount = @4;
    self.config.onlyRetryFailed = TRUE;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);
}




- (void)testRetryOnlyFailures {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @100;
    self.config.failureTolerance = @1;
    self.config.onlyRetryFailed = TRUE;
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
    self.config.errorRetriesCount = @1;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);
}

- (void)testRunWithFailingTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.failureTolerance = @0;
    self.config.testCaseTimeout = @10;
    self.config.testCasesToRun = @[@"BPAppNegativeTests/testBPDoesNotHangWithBigOutput"];
    self.config.errorRetriesCount = @1;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppFailingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode != BPExitStatusTestTimeout);
    XCTAssert(exitCode == BPExitStatusTestsFailed);
}

//simulator shouldn't be kept in this case
- (void)testKeepSimulatorWithAppCrashingTestsSet  {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    self.config.errorRetriesCount = @1;

    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusAppCrashed);

}

//simulator shouldn't be kept in this case
- (void)testKeepSimulatorWithAppHangingTestsSet  {
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;
    self.config.testing_ExecutionPlan = @"TIMEOUT";

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
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);
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
    [BPUtils enableDebugOutput:YES];
    // The delay of ui test bootstrapping is larger than 5s.
    self.config.testCaseTimeout = @300;
    self.config.errorRetriesCount = @1;
    NSString *testBundlePath = [BPTestHelper sampleAppUITestBundlePath];
    NSString *testRunnerPath = [BPTestHelper sampleAppUITestRunnerPath];
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/UITestsSetTempDir", tempDir] withError:&error];
    self.config.testRunnerAppPath = testRunnerPath;
    self.config.testBundlePath = testBundlePath;
    self.config.outputDirectory = outputDir;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    self.config.testRunnerAppPath = nil;
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);
}


- (void)testCopySimulatorPreferencesFile {
    self.config.simulatorPreferencesFile = [BPTestHelper.resourceFolderPath stringByAppendingPathComponent:@"simulator-preferences.plist"];

    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;

    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);

    NSURL *preferencesFile = bp.test_simulator.preferencesFile;

    NSDictionary *plist = [[NSDictionary alloc] initWithContentsOfURL:preferencesFile];
    XCTAssertEqualObjects(@"en_CN", plist[@"AppleLocale"]);

    self.config.deleteSimUDID = bp.test_simulatorUDID;
    XCTAssertNotNil(self.config.deleteSimUDID);

    Bluepill *bp2 = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp2 run];
    XCTAssert(exitCode2 == BPExitStatusSimulatorDeleted);
    XCTAssertEqualObjects(self.config.deleteSimUDID, bp2.test_simulatorUDID);

    XCTAssert([[NSDictionary alloc] initWithContentsOfURL:preferencesFile] == nil);
}

- (void)testRunScript {
    self.config.scriptFilePath = [BPTestHelper sampleScriptPath];

    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.keepSimulator = YES;

    Bluepill *bp = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode = [bp run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed);
    XCTAssertNotNil(bp.test_simulatorUDID);

    NSString *devicePath = bp.test_simulator.device.devicePath;
    NSString *deviceID = bp.test_simulator.device.UDID.UUIDString;

    // The test script will create $(DEVICE_ID).txt in the device path
    NSString *testFile = [NSString stringWithFormat:@"%@/%@.txt", devicePath, deviceID];
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:testFile]);

    self.config.deleteSimUDID = bp.test_simulatorUDID;
    XCTAssertNotNil(self.config.deleteSimUDID);

    Bluepill *bp2 = [[Bluepill alloc ] initWithConfiguration:self.config];
    BPExitStatus exitCode2 = [bp2 run];
    XCTAssert(exitCode2 == BPExitStatusSimulatorDeleted);
    XCTAssertEqualObjects(self.config.deleteSimUDID, bp2.test_simulatorUDID);

    if ([[NSFileManager defaultManager] fileExistsAtPath:testFile]) {
        [[NSFileManager defaultManager] removeItemAtPath:testFile error:nil];
        XCTFail(@"%@ was not deleted when the simulator was deleted", testFile);
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


@end
