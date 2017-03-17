//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "SimulatorMonitor.h"
#import "SimDevice.h"
#import "BPConfiguration.h"
#import "BPStats.h"
#import "BPUtils.h"

@interface SimulatorMonitor ()

@property (nonatomic, weak) id<BPMonitorCallbackProtocol> callback;

@property (nonatomic, strong) NSDate *lastOutput;
@property (nonatomic, strong) NSDate *lastTestCaseStartDate;
@property (nonatomic, strong) NSString *currentTestName;
@property (nonatomic, strong) NSString *currentClassName;
@property (nonatomic, strong) NSString *previousTestName;
@property (nonatomic, strong) NSString *previousClassName;
@property (nonatomic, assign) BPExitStatus exitStatus;
@property (nonatomic, assign) NSUInteger currentOutputId;
@property (nonatomic, assign) NSUInteger failureCount;
@property (nonatomic, assign) BOOL testsBegan;
@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) NSMutableArray *executedTests;

@end

@implementation SimulatorMonitor

- (instancetype)initWithConfiguration:(BPConfiguration *)config {
    self = [super init];
    if (self) {
        self.config = config;
        self.maxTimeWithNoOutput = [config.stuckTimeout integerValue];
        self.maxTestExecutionTime = [config.testCaseTimeout integerValue];
        self.simulatorState = Idle;
        self.exitStatus = 0;
    }
    return self;
}

- (void)setMonitorCallback:(id<BPMonitorCallbackProtocol>)callback {
    self.callback = callback;
}

- (void)onAllTestsBegan {
    self.simulatorState = Running;
    // Don't overwrite the original start time on secondary attempts
    if ([BPStats sharedStats].cleanRun) {
        [BPStats sharedStats].cleanRun = NO;
        [[BPStats sharedStats] startTimer:ALL_TESTS];
    }
    [BPUtils printInfo:INFO withString:@"All Tests started."];
}

- (void)onAllTestsEnded {
    self.simulatorState = Completed;
    if (self.failureCount) {
        self.exitStatus = BPExitStatusTestsFailed;
    } else {
        self.exitStatus = BPExitStatusTestsAllPassed;
    }
    [[BPStats sharedStats] endTimer:ALL_TESTS];
    [BPUtils printInfo:INFO withString:@"All Tests Completed."];
}

- (void)onTestCaseBeganWithName:(NSString *)testName inClass:(NSString *)testClass {
    [[BPStats sharedStats] startTimer:[NSString stringWithFormat:TEST_CASE_FORMAT, [BPStats sharedStats].attemptNumber, testClass, testName]];
    self.lastTestCaseStartDate = [NSDate date];

    self.simulatorState = TestsStarted;

    self.currentTestName = testName;
    self.currentClassName = testClass;

    __weak typeof(self) __self = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.maxTestExecutionTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([__self.currentTestName isEqualToString:testName] && [__self.currentClassName isEqualToString:testClass] && __self.simulatorState == TestsStarted) {
            [BPUtils printInfo:TIMEOUT withString:@"%10.6fs %@/%@", __self.maxTestExecutionTime, testClass, testName];
            [__self stopTestsWithErrorMessage:@"Test took too long to execute and was aborted." forTestName:testName inClass:testClass];
            __self.exitStatus = BPExitStatusTestTimeout;
            [[BPStats sharedStats] endTimer:[NSString stringWithFormat:TEST_CASE_FORMAT, [BPStats sharedStats].attemptNumber, testClass, testName]];
            [[BPStats sharedStats] addTestRuntimeTimeout];
        }
    });
    [[BPStats sharedStats] addTest];
}

- (void)onTestCasePassedWithName:(NSString *)testName inClass:(NSString *)testClass reportedDuration:(NSTimeInterval)duration {
    NSDate *currentTime = [NSDate date];
    [BPUtils printInfo:PASSED withString:@"%10.6fs %@/%@",
                                          [currentTime timeIntervalSinceDate:self.lastTestCaseStartDate],
                                          testClass, testName];

    // Passing or failing means that if the simulator crashes later, we shouldn't rerun this test.
    [self updateExecutedTestCaseList:testName inClass:testClass];
    // If the current test name is nil, it likely means we have an intermixed crash and should actually use this reported pass status
    self.previousTestName = self.currentTestName ?: self.previousTestName;
    self.previousClassName = self.currentClassName ?: self.previousClassName;
    self.currentTestName = nil;
    self.currentClassName = nil;
    [[BPStats sharedStats] endTimer:[NSString stringWithFormat:TEST_CASE_FORMAT, [BPStats sharedStats].attemptNumber, testClass, testName]];
}

- (void)onTestCaseFailedWithName:(NSString *)testName inClass:(NSString *)testClass
                          inFile:(NSString *)filePath onLineNumber:(NSUInteger)lineNumber wasException:(BOOL)wasException {
    NSDate *currentTime = [NSDate date];
    [BPUtils printInfo:FAILED withString:@"%10.6fs %@/%@",
                                          [currentTime timeIntervalSinceDate:self.lastTestCaseStartDate],
                                          testClass, testName];
    self.failureCount++;

    // Passing or failing means that if the simulator crashes later, we shouldn't rerun this test. Unless we've enabled re-running failed tests.
    if (self.config.onlyRetryFailed == NO) {
        [self updateExecutedTestCaseList:testName inClass:testClass];
    }
    self.previousTestName = self.currentTestName ?: self.previousTestName;
    self.previousClassName = self.currentClassName ?: self.previousClassName;
    self.currentTestName = nil;
    self.currentClassName = nil;
    [[BPStats sharedStats] endTimer:[NSString stringWithFormat:TEST_CASE_FORMAT, [BPStats sharedStats].attemptNumber, testClass, testName]];
    [[BPStats sharedStats] addTestFailure];
    if (wasException) {
        [[BPStats sharedStats] addTestError];
    }
}

- (void)updateExecutedTestCaseList:(NSString *)testName inClass:(NSString *)testClass {
    if (testName == nil || testClass == nil) {
        [BPUtils printInfo:DEBUGINFO withString:@"Attempting to add empty test name or class to the executed list"];
        return;
    }
    if (self.executedTests == nil) {
        self.executedTests = [[NSMutableArray alloc] init];
    }
    [self.executedTests addObject:[testClass stringByAppendingFormat:@"/%@", testName]];
    if (self.config.testCasesToSkip == nil) {
        self.config.testCasesToSkip = @[];
    }
    // If we crash, on the re-execution, we'll have a new list of tests to skip because we already ran these to completion.

    self.config.testCasesToSkip = [self.config.testCasesToSkip arrayByAddingObjectsFromArray:self.executedTests];
}

- (void)onTestSuiteBegan:(NSString *)testSuiteName onDate:(NSDate *)startDate isRoot:(BOOL)isRoot {
    [[BPStats sharedStats] startTimer:[NSString stringWithFormat:TEST_SUITE_FORMAT, isRoot ? 1 : [BPStats sharedStats].attemptNumber, testSuiteName]];
}

- (void)onTestSuiteEnded:(NSString *)testSuiteName
                fromDate:(NSDate *)startDate
                  toDate:(NSDate *)endDate
                  passed:(BOOL)wholeSuitePassed
               withTotal:(NSUInteger)totalTestCount
                  failed:(NSUInteger)failedCount
              unexpected:(NSUInteger)unexpectedFailures
                  isRoot:(BOOL)isRoot {
    [[BPStats sharedStats] endTimer:[NSString stringWithFormat:TEST_SUITE_FORMAT, isRoot ? 1 : [BPStats sharedStats].attemptNumber, testSuiteName]];
}

- (void)onOutputReceived:(NSString *)output {
    NSDate *currentTime = [NSDate date];

    if (self.simulatorState == Idle) {
        self.simulatorState = AppLaunched;
    }

    self.currentOutputId++; // Increment the Output ID for this instance since we've moved on to the next bit of output

    __block NSUInteger previousOutputId = self.currentOutputId;
    __weak typeof(self) __self = self;

    // App crashed
    if ([output isEqualToString:@"BP_APP_PROC_ENDED"] && __self.simulatorState == TestsStarted) {
        [BPUtils printInfo:CRASH withString:@"%@/%@ crashed app.",
                                             (self.currentClassName ?: self.previousClassName),
                                             (self.currentTestName ?: self.previousTestName)];
        [self stopTestsWithErrorMessage:@"App Crashed"
                              forTestName:(self.currentTestName ?: self.previousTestName)
                                  inClass:(self.currentClassName ?: self.previousClassName)];
        self.exitStatus = BPExitStatusAppCrashed;
        [[BPStats sharedStats] addApplicationCrash];
    }
    self.maxTimeWithNoOutput = 30; // TO BE REMOVED
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(__self.maxTimeWithNoOutput * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (__self.currentOutputId == previousOutputId && (__self.simulatorState >= AppLaunched && __self.simulatorState != Completed)) {
            NSString *testClass = (__self.currentClassName ?: __self.previousClassName);
            NSString *testName = (__self.currentTestName ?: __self.previousTestName);
            if (testClass == nil && testName == nil && (__self.simulatorState < TestsStarted)) {
                [BPUtils printInfo:ERROR withString:@"It appears that tests have not yet started. The test app has frozen prior to the first test."];
            } else {
                [BPUtils printInfo:TIMEOUT withString:@" %10.6fs waiting for output from %@/%@",
                 __self.maxTimeWithNoOutput, testClass, testName];
                [[BPStats sharedStats] endTimer:[NSString stringWithFormat:TEST_CASE_FORMAT, [BPStats sharedStats].attemptNumber, testClass, testName]];
            }
            // Set exit status before stopping the tests because stopping the tests will set the SimulatorState to Completed
            __self.exitStatus = [self didTestsStart] ? BPExitStatusTestTimeout : BPExitStatusAppCrashed;
            [__self stopTestsWithErrorMessage:@"Timed out waiting for the test to produce output. Test was aboorted."
                                  forTestName:testName
                                      inClass:testClass];
            [[BPStats sharedStats] addTestOutputTimeout];
        }
    });
    self.lastOutput = currentTime;
}

- (void)stopTestsWithErrorMessage:(NSString *)message forTestName:(NSString *)testName inClass:(NSString *)testClass {

    // Timeout or crash on a test means we should skip it when we rerun the tests, unless we've enabled re-running failed tests
    if (!self.config.onlyRetryFailed) {
        [self updateExecutedTestCaseList:testName inClass:testClass];
    }

    if (![[self.device stateString] isEqualToString:@"Shutdown"] && !self.config.testing_NoAppWillRun) {
        [BPUtils printInfo:ERROR withString:@"Will kill the process with appPID: %d", self.appPID];
        NSAssert(self.appPID > 0, @"Failed to find a valid PID");
        if ((kill(self.appPID, 0) == 0) && (kill(self.appPID, SIGKILL) < 0)) {
            [BPUtils printInfo:ERROR withString:@"Failed to kill the process with appPID: %d: %s",
                self.appPID, strerror(errno)];
        }
    }

    self.simulatorState = Completed;
    [self.callback onTestAbortedWithName:testName inClass:testClass errorMessage:message];
}

- (BOOL)isExecutionComplete {
    return (self.simulatorState == Completed);
}

- (BOOL)isApplicationStarted {
    return (self.simulatorState != Idle);
}

- (BOOL)didTestsStart {
    return (self.simulatorState >= Running);
}

@end
