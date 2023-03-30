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
#import "BPTestUtils.h"

/**
 * This test suite is the integration tests to make sure logic tests are being run correctly.
 * It includes validation on the following:
 *  - Exit code testing
 *  - Failure/Timeout/Crash handling
 *  - Retry behaviors
 */
@interface BluepillUnhostedTests : BPIntTestCase
@end

@implementation BluepillUnhostedTests

- (void)setUp {
    [super setUp];
    self.config = [BPTestUtils makeUnhostedTestConfiguration];
    self.config.numSims = @1;
    self.config.stuckTimeout = @1;

    NSString *testBundlePath = [BPTestHelper logicTestBundlePath];
    self.config.testBundlePath = testBundlePath;
}

#pragma mark - Passing Tests

- (void)testSinglePassingLogicTests {
    self.config.testCasesToRun = @[@"BPLogicTests/testPassingLogicTest1"];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAllTestsPassed];
}

- (void)testMultiplePassingLogicTests {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/TestLogsTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.testCasesToRun = @[
        @"BPLogicTests/testPassingLogicTest1",
        @"BPLogicTests/testPassingLogicTest2"
    ];

    // Run Tests
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAllTestsPassed];
    
    // Check that test is started in both sets of logs.
    for (NSString *testCase in self.config.testCasesToRun) {
        XCTAssert([BPTestUtils checkIfTestCase:testCase bundleName:@"BPLogicTests" wasRunInLog:[outputDir stringByAppendingPathComponent:@"1-simulator.log"]]);
    }
}

# pragma mark - Failing Tests

- (void)testFailingLogicTest {
    self.config.testCasesToRun = @[@"BPLogicTests/testFailingLogicTest"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusTestsFailed];
}

#pragma mark - Handling Crashes

/*
 A boring objective-c crash (such as index out of bounds on an NSArray) should be
 handled smoothly by XCTest, and reported as such as a failed test.
 */
- (void)testCrashingTestCaseLogicTest {
    self.config.testCasesToRun = @[@"BPLogicTests/testCrashTestCaseLogicTest"];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusTestsFailed];
}

/*
 A more aggressive crash (like doing an illegal strcpy) will crash the entire XCTest
 execution.
 */
- (void)testCrashingExecutionLogicTest {
    self.config.testCasesToRun = @[@"BPLogicTests/testCrashExecutionLogicTest"];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAppCrashed];
}

#pragma mark - Timeouts

/*
 This test validates that a test fails when the simulator has no output for over
 the stuckTimeout threshold
 */
- (void)testStuckLogicTest {
    self.config.testCasesToRun = @[@"BPLogicTests/testStuckLogicTest"];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusTestTimeout];
}

/*
 This test validates that a slow test will fail, even when the simulator sees
 some change.
 */
- (void)testHangingLogicTest {
    // `BPLogicTests/testSlowLogicTest` is designed to log a string infinitely, once a second.
    // As a result, it should not "get stuck", but should eventually timeout anyway.
    self.config.stuckTimeout = @1;
    self.config.testCaseTimeout = @3;
    self.config.testCasesToRun = @[@"BPLogicTests/testSlowLogicTest"];

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusTestTimeout];
}

/*
 The timeout should only cause a failure if an individual test exceeds the timeout,
 not if the combined time sums to above the timeout.
 */
- (void)testTimeoutOnlyAppliesToTestCaseNotSuite {
    // The three tests combined should exceed any timeouts, but that shouldn't be a problem.
    self.config.testCaseTimeout = @2;
    self.config.stuckTimeout = @2;
    self.config.testCasesToRun = @[
        @"BPLogicTests/testOneSecondTest1",
        @"BPLogicTests/testOneSecondTest2",
        @"BPLogicTests/testOneSecondTest3",
    ];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAllTestsPassed];
}

#pragma mark - Retries

- (void)testRetriesFailure {
    [self validateTestIsRetried:@"BPLogicTests/testFailingLogicTest"];
}

- (void)testRetriesCrash {
    self.config.retryAppCrashTests = YES;
    [self validateTestIsRetried:@"BPLogicTests/testCrashExecutionLogicTest"];
}

#pragma mark - Helpers

- (void)validateTestIsRetried:(NSString *)testCase {
    // Setup
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @1;
    self.config.failureTolerance = @1;
    self.config.testCasesToRun = @[testCase];
    
    // Run Tests
    __unused BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    
    // Validate
    XCTAssert([BPTestUtils checkIfTestCase:testCase bundleName:@"BPLogicTests" wasRunInLog:[outputDir stringByAppendingPathComponent:@"1-simulator.log"]]);
    XCTAssert([BPTestUtils checkIfTestCase:testCase bundleName:@"BPLogicTests" wasRunInLog:[outputDir stringByAppendingPathComponent:@"2-simulator.log"]]);
}

@end
