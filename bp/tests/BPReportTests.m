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
#import "BPIntTestCase.h"
#import "BPSimulator.h"
#import "BPTestHelper.h"
#import "BPUtils.h"

@interface BPReportTests : BPIntTestCase
- (NSString *)sanitizeXMLFile:(NSString *)atPath;
- (void)assertGotReport:(NSString *)Got isEqualToWantReport:(NSString *)Want;
@end

@implementation BPReportTests

#pragma mark - Test helpers

- (NSString *)sanitizeXMLFile:(NSString *)atPath {
    NSString *XSLTemplate = @" \
    <xsl:stylesheet version=\"1.0\" xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\"> \
    <!--empty template suppresses these attributes --> \
    <xsl:template match=\"@time\" /> \
    <xsl:template match=\"@timestamp\" /> \
    <!--empty template suppresses these elements --> \
    <xsl:template match=\"system-out/text()\"/> \
    <xsl:template match=\"failure/text()\"/> \
    <xsl:template match=\"error/text()\"/> \
    <!--identity template copies everything forward by default--> \
    <xsl:template match=\"@*|node()\"> \
    <xsl:copy> \
    <xsl:apply-templates select=\"@*|node()\"/> \
    </xsl:copy> \
    </xsl:template> \
    </xsl:stylesheet> \
    ";
    NSError *error;
    NSURL *sourceURL = [NSURL fileURLWithPath:atPath];
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:sourceURL options:0 error:&error];
    XCTAssert(xmlDoc != nil, @"%@", [error localizedDescription]);
    NSData *XSLTransform = [XSLTemplate dataUsingEncoding:NSUTF8StringEncoding];
    NSXMLDocument *sanitizedXMLDoc = [xmlDoc objectByApplyingXSLT:XSLTransform arguments:nil error:&error];
    XCTAssert(sanitizedXMLDoc != nil, @"%@", [error localizedDescription]);
    NSString *outFile = [BPUtils mkstemp:@"outXXX.xslt" withError:&error];
    XCTAssert(outFile != nil, @"%@", [error localizedDescription]);
    NSData *outData = [sanitizedXMLDoc XMLDataWithOptions:NSXMLNodePrettyPrint];
    if (![outData writeToFile:outFile atomically:YES]) {
        XCTAssert(false, @"Failed to write file: %@", outFile);
    }
    return outFile;
}

- (void)assertGotReport:(NSString *)Got isEqualToWantReport:(NSString *)Want {
    NSString *sanitizedGot = [self sanitizeXMLFile:Got];
    NSString *sanitizedWant = [self sanitizeXMLFile:Want];
    // we ignore white space (-b) just as a convenience to test writers
    NSString *diffOutput = [BPUtils runShell:[NSString stringWithFormat:@"diff -u -b '%@' '%@'", sanitizedWant, sanitizedGot]];
    XCTAssert(diffOutput != nil && [diffOutput isEqualToString:@""], @"\ndiff -u -b '%@' '%@':\n%@", sanitizedWant, sanitizedGot, diffOutput);
}
@end

@interface BPReportTests1 : BPReportTests
@end

@implementation BPReportTests1


- (void)testReportWithAppCrashingTestsSet {
    [BPUtils enableDebugOutput:NO];
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppCrashingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @1;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);
    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppCrashingTests-1-results.xml"];
    NSLog(@"JUnit-REPORT: %@", junitReportPath);
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests_attempt_1.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];

    junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppCrashingTests-2-results.xml"];
    expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests_attempt_2.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
}

- (void)testReportWithAppCrashingAndRetryOnlyFailedTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppCrashingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @1;
    self.config.failureTolerance = @1;
    self.config.onlyRetryFailed = TRUE;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppCrashingTests-1-results.xml"];
    NSLog(@"JUnit file: %@", junitReportPath);
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests_with_retry_attempt_1.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];

    junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppCrashingTests-2-results.xml"];
    expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"crash_tests_with_retry_attempt_2.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
}

// TODO: Enable this while re-enabling the fix from PR#338
- (void)DISABLE_testAppCrashingAndRetryReportsCorrectExitCode {
    NSString *testBundlePath = [BPTestHelper sampleAppCrashingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppCrashingTestsSetTempDir", tempDir] withError:&error];
    self.config.outputDirectory = outputDir;
    self.config.testing_crashOnAttempt = @1;
    self.config.errorRetriesCount = @2;
    self.config.failureTolerance = @1;
    self.config.onlyRetryFailed = TRUE;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

- (void)testReportWithFatalErrorTestsSet {
    NSString *testBundlePath = [BPTestHelper sampleAppFatalTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppFatalErrorTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.errorRetriesCount = @2;
    self.config.testCaseTimeout = @30; // make sure we don't time-out

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);

    for (NSNumber *attempt in @[@1, @2, @3]) {
        NSString *fileName = [NSString stringWithFormat:@"TEST-BPSampleAppFatalErrorTests-%@-results.xml", attempt];
        NSString *junitReportPath = [outputDir stringByAppendingPathComponent:fileName];
        NSLog(@"JUnit file: %@", junitReportPath);
        fileName = [NSString stringWithFormat:@"fatal_tests_attempt_%@.xml", attempt];
        NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:fileName];
        [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
    }
}

- (void)testReportWithAppHangingTestsSet {
    // Testcase timeout should be set larger than the stuck timeout
    self.config.testCaseTimeout = @20;
    self.config.stuckTimeout = @15;
    self.config.errorRetriesCount = @0;
    self.config.testing_ExecutionPlan = @"TIMEOUT";
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusTestTimeout);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppHangingTests-1-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"hanging_tests.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
}

/**
 The scenario is:
 - if a test timeout or crashed, even if we proceed to the next test, we should still return error exit code.
 */
- (void)testReportWithAppHangingTestsShouldReturnFailure {
    self.config.stuckTimeout = @6;
    self.config.failureTolerance = @0;
    self.config.errorRetriesCount = @4;
    self.config.testing_ExecutionPlan = @"TIMEOUT";
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    // NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusTestTimeout);

    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPSampleAppHangingTests-1-results.xml"];
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"hanging_tests.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
}

/**
 Execution plan: TIMEOUT, CRASH (not retried)
 */
- (void)testReportFailureOnTimeoutCrashAndPass {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"TIMEOUT CRASH";
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

/**
 Execution plan: TIMEOUT, CRASH, CRASH w/ flag to retry crashes and consider them non-fatal
 */
- (void)testReportFailureOnTimeoutCrashAndCrashOnRetry {
    self.config.stuckTimeout = @6;
    self.config.retryAppCrashTests = TRUE;
    self.config.testing_ExecutionPlan = @"TIMEOUT CRASH CRASH";
    self.config.errorRetriesCount = @2;
    self.config.onlyRetryFailed = TRUE;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == (BPExitStatusTestTimeout | BPExitStatusAppCrashed));
}

/**
 Execution plan: TIMEOUT, CRASH, PASS w/ flag to retry crashes and consider them non-fatal
 */
- (void)testReportSuccessOnTimeoutCrashAndPassOnRetry {
    self.config.stuckTimeout = @6;
    self.config.retryAppCrashTests = TRUE;
    self.config.testing_ExecutionPlan = @"TIMEOUT CRASH PASS";
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
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

/**
 Execution plan: One test CRASHes and another one TIMEs OUT and PASSes on retry
 */
- (void)testReportFailureOnCrashAndTimeoutTests {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"CRASH; SKIP TIMEOUT PASS";
    self.config.onlyRetryFailed = TRUE;
    self.config.failureTolerance = @1;
    self.config.errorRetriesCount = @2;
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

/**
 Execution plan: Test crashes but passes on retry w/ retry app crash tests flag set
 */
- (void)testReportSuccessOnAppCrashTestPassesOnRetry {
    self.config.stuckTimeout = @6;
    self.config.retryAppCrashTests = TRUE;
    self.config.testing_ExecutionPlan = @"CRASH PASS; SKIP PASS";
    self.config.onlyRetryFailed = TRUE;
    self.config.failureTolerance = @1;
    self.config.errorRetriesCount = @2;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

@end

@interface BPReportTests2 : BPReportTests
@end

@implementation BPReportTests2

/**
 Execution plan: One test CRASHes and another one keeps timing out
 */
- (void)testReportBothCrashAndTimeout {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"CRASH; SKIP TIMEOUT TIMEOUT";
    self.config.onlyRetryFailed = TRUE;
    self.config.failureTolerance = @1;
    self.config.errorRetriesCount = @2;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == (BPExitStatusAppCrashed | BPExitStatusTestTimeout));
}

/**
 Execution plan: FAIL, TIMEOUT, PASS
 */
- (void)testReportSuccessOnFailTimeoutAndPass {
    self.config.stuckTimeout = @6;
    self.config.failureTolerance = @1;
    self.config.testing_ExecutionPlan = @"FAIL TIMEOUT PASS";
    self.config.errorRetriesCount = @3;
    self.config.onlyRetryFailed = TRUE;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

/**
 Execution plan: FAIL, TIMEOUT, PASS
 */
- (void)testReportFailureOnFailTimeoutAndPass {
    self.config.stuckTimeout = @6;
    self.config.failureTolerance = @0;
    self.config.testing_ExecutionPlan = @"FAIL TIMEOUT PASS";
    self.config.errorRetriesCount = @3;
    self.config.onlyRetryFailed = TRUE;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusTestsFailed);
}

/**
 Execution plan: TIMEOUT, PASS
 */
- (void)testReportSuccessOnTimeoutAndPassOnRetry {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"TIMEOUT PASS";
    self.config.errorRetriesCount = @4;
    self.config.onlyRetryFailed = TRUE;
    self.config.failureTolerance = @0;  // Not relevant
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

/**
 Execution plan: TIMEOUT (NO RETRY))
 */
- (void)testReportFailureOnTimeoutAndNoRetry {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"TIMEOUT";
    self.config.errorRetriesCount = @2;
    self.config.onlyRetryFailed = FALSE;
    self.config.failureTolerance = @1;  // Not relevant since it's not a test failure
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusTestTimeout);
}

/**
 Execution plan: FAIL  and PASS on retry all
 */
- (void)testReportSuccessOnFailedTestAndPassOnRetryAll {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"FAIL PASS";
    self.config.errorRetriesCount = @4;
    self.config.onlyRetryFailed = NO;  // Indicates to retry all tests when a test fails
    self.config.failureTolerance = @1;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/AppHangingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

/**
 Execution plan: FAIL, PASS
 */
- (void)testReportSuccessOnTestFailedAndPassOnRetry {
    self.config.stuckTimeout = @6;
    self.config.failureTolerance = @1;
    self.config.testing_ExecutionPlan = @"FAIL PASS";
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
    XCTAssertTrue(exitCode == BPExitStatusAllTestsPassed);
}

- (void)testReportWithFailingTestsSet {
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.testCasesToSkip = @[@"BPAppNegativeTests/testBPDoesNotHangWithBigOutput"];
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
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
    NSString *junitReportPath = [outputDir stringByAppendingPathComponent:@"TEST-BPAppNegativeTests-1-results.xml"];
    NSLog(@"Junit report: %@", junitReportPath);
    NSString *expectedFilePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"BPAppNegativeTests-results.xml"];
    [self assertGotReport:junitReportPath isEqualToWantReport:expectedFilePath];
    XCTAssert(exitCode == BPExitStatusTestsFailed);
}

/**
 Execution plan: TIMEOUT, CRASH (not retried)
 */
- (void)testReportFailureOnTimeoutCrashAndPassWithDiagnostics {
    self.config.stuckTimeout = @6;
    self.config.testing_ExecutionPlan = @"TIMEOUT CRASH";
    self.config.errorRetriesCount = @4;
    self.config.onlyRetryFailed = TRUE;
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    NSString *outputDir = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/FailingTestsSetTempDir", tempDir] withError:&error];
    NSLog(@"output directory is %@", outputDir);
    self.config.outputDirectory = outputDir;
    self.config.saveDiagnosticsOnError = YES;
    NSString *testBundlePath = [BPTestHelper sampleAppHangingTestsBundlePath];
    self.config.testBundlePath = testBundlePath;

    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    NSFileManager *fm = [NSFileManager defaultManager];
    [BPUtils runShell:[NSString stringWithFormat:@"find %@", outputDir]];
    BOOL diagFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/diagnostics.tar.gz", outputDir]];
    XCTAssert(diagFileFound);
    BOOL psFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/ps-axuw.log", outputDir]];
    XCTAssert(psFileFound);
    BOOL dfFileFound = [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/df-h.log", outputDir]];
    XCTAssert(dfFileFound);
    XCTAssertTrue(exitCode == BPExitStatusAppCrashed);
}

@end
