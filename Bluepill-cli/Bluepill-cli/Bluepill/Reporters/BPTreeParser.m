//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTreeParser.h"
#import "BPTreeObjects.h"
#import "BPReporters.h"
#import "BPExecutionPhaseProtocol.h"
#import "BPWriter.h"
#import "BPUtils.h"
#import "BPTreeAssembler.h"
#import <time.h>
#import <xlocale.h>

static const NSString * const kTestSuiteName = @"testSuiteName";
static const NSString * const kStartTime = @"startTime";
static const NSString * const kEndTime = @"endTime";
static const NSString * const kLog = @"log";
static const NSString * const kChildKey = @"child";

static const NSString * const kStarted = @"started";
static const NSString * const kPassed = @"passed";

@interface BPTreeParser () <BPExecutionPhaseProtocol, BPMonitorCallbackProtocol>

@property (nonatomic, strong) BPWriter *log;

@property (nonatomic, strong) NSString *line;
@property (nonatomic, strong) BPTestSuiteLogEntry *root;
@property (nonatomic, assign) BPTestSuiteLogEntry *current;
@property (nonatomic, assign) BPTestCaseLogEntry *currentTest;

// This variable exists because the name of the root node can change between
// The first run and a second run after a crash.
// So in order to recognize that we closed the node in the second run that
// we opened in the first run, we need to know what the new name is and track it
@property (nonatomic, strong) NSString *currentRootName;
@property (nonatomic, assign) BOOL hasRoot;
@property (nonatomic, assign) BOOL testsBegan;
@property (nonatomic, assign) BOOL aborted;

@property (nonatomic, assign) BOOL moveToParent;

@end

@implementation BPTreeParser

- (instancetype)initWithWriter:(BPWriter *)writer {
    self = [super init];
    if (self) {
        self.line = @"";
        self.log = writer;
        [self writeHeader];
    }
    return self;
}

- (BPTestSuiteLogEntry *)root {
    return [BPTreeAssembler sharedInstance].root;
}

- (void)setRoot:(BPTestSuiteLogEntry *)root {
    [BPTreeAssembler sharedInstance].root = root;
}

- (BPTestSuiteLogEntry *)current {
    return [BPTreeAssembler sharedInstance].current;
}

- (void)setCurrent:(BPTestSuiteLogEntry *)current {
    [BPTreeAssembler sharedInstance].current = current;
}

- (BPTestCaseLogEntry *)currentTest {
    return [BPTreeAssembler sharedInstance].currentTest;
}

- (void)setCurrentTest:(BPTestCaseLogEntry *)currentTest {
    [BPTreeAssembler sharedInstance].currentTest = currentTest;
}

- (void)writeHeader {
    [self.log writeLine:@"%@", @"--------------------------------------------------------------------------------"];
    [self.log writeLine:@"Tests started: %@", [NSDate date]];
    [self.log writeLine:@"%@", @"--------------------------------------------------------------------------------"];
}

- (void)handleChunkData:(nonnull NSData *)chunk {
    if ([chunk length] > 0) {
        NSString *str = [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding];
        NSRange range = [str rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
        while (range.location != NSNotFound) {
            self.line = [self.line stringByAppendingString:[str substringToIndex:range.location] ?: @""];
            [self.log writeLine:@"%@", self.line];
            [self parseLine:self.line];
            self.line = @"";
            str = [str substringFromIndex:range.location+range.length];
            range = [str rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
        }
        self.line = str;
    }
}

- (void)parseLine:(nullable NSString *)line {
    [BPUtils printInfo:DEBUGINFO withString:@"[OUTPUT] %@", line];
    [self onOutputReceived:line];
    if (!line || ![line length]) {
        return;
    }

    NSRange lineRange = NSMakeRange(0, [line length]);
    BOOL logLine = YES;
    NSRegularExpression *regex;
    NSArray *matches;

    if ([line isEqualToString:@"BP_APP_PROC_ENDED"]) {
        logLine = NO;
    }

    // 	 Executed 9 tests, with 2 failures (1 unexpected) in 2.980 (3.206) seconds
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_SUITE_ENDED options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 6) {
            logLine = NO;
            NSString *numberOfTestsString = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *numberOfFailuresString = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *numberOfUnexpectedString = [line substringWithRange:[result rangeAtIndex:3]];
            NSString *time2String = [line substringWithRange:[result rangeAtIndex:5]];

            self.current.reportedNumberOfTests = [numberOfTestsString integerValue];
            self.current.reportedNumberOfFailures = [numberOfFailuresString integerValue];
            self.current.reportedNumberOfUnexpected = [numberOfUnexpectedString integerValue];
            self.current.reportedTotalTime = [time2String doubleValue];

            [self onTestSuiteEnded:self.current.testSuiteName
                          fromDate:self.current.startTime
                            toDate:self.current.endTime
                            passed:self.current.passed
                         withTotal:self.current.numberOfTests
                            failed:self.current.numberOfUnexpected
                        unexpected:self.current.numberOfUnexpected
                            isRoot:(self.current == self.root)];
        }
    }

    // If we made it past the check for "Executed..." while moveToParent was YES, then either:
    // - We handled the "Executed..." line and therefore are free to move to the parent
    // - There was no "Executed..." line and therefore we are free to move to the parent
    // After moving, reset the flag back to 0.
    if (self.moveToParent && self.current.parent) {
        self.current = self.current.parent;
    }
    self.moveToParent = NO;

    // Test Suite 'mntf_UISwiftTests' started at 2016-10-07 12:52:05.091
    // Test Suite 'Debug-iphonesimulator' passed at 2016-10-07 12:52:05.091.
    // Test Suite 'mntf_UISwiftTests' failed at 2016-10-07 12:52:08.297.
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_SUITE_START options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 4) {
            logLine = NO;
            NSString *testSuiteName = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *started = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *dateString = [line substringWithRange:[result rangeAtIndex:3]];

            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"YYYY-MM-dd HH:mm:ss.SSS";
            NSDate *date = [dateFormatter dateFromString:dateString];

            BOOL start = [kStarted isEqualToString:started];
            if (start) {
                BPTestSuiteLogEntry *logEntry = [[BPTestSuiteLogEntry alloc] init];
                if (!self.root) {
                    self.root = logEntry;
                    self.current = self.root;
                    self.hasRoot = YES;
                    self.currentRootName = testSuiteName;
                } else {
                    if (!self.hasRoot) {
                        // We're on a secondary run where we have a root node but this execution does not yet have a root.
                        // It pretty much means we should ignore this suite and everything should be added to the current root.
                        // Plus reset the 'current' nodes.
                        self.current = self.root;
                        self.currentTest = nil;
                        self.hasRoot = YES;
                        self.currentRootName = testSuiteName;
                        // Force the root node to 'open' again. See below for more information.
                        self.root.ended = NO;
                        continue;
                    }
                    [self.current addChild:logEntry];
                    logEntry.parent = self.current;
                    self.current = logEntry;
                }
                self.current.testSuiteName = testSuiteName;
                self.current.startTime = date;
                self.current.line = line;
                // Force the node to 'open' again because we could be running more tests in a suite from a previous crash
                // By forcing the node to not ended, we'll allow it to be closed again after more children are appended
                // Since this is always the start of a node, there is no reason it shouldn't be open at this point
                self.current.ended = NO;

                [self onTestSuiteBegan:testSuiteName onDate:date isRoot:(self.current == self.root)];
            } else {
                // An ending block
                // It either has to close the current node
                // Or it has to close the parent node
                BPTestSuiteLogEntry *node = self.current;
                if (([node.testSuiteName isEqualToString:testSuiteName] || [self.currentRootName isEqualToString:testSuiteName]) && node.ended == NO) {
                    self.current = node;
                } else if (([node.parent.testSuiteName isEqualToString:testSuiteName]) && node.parent.ended == NO) {
                    self.current = node.parent;
                } else {
                    [BPUtils printInfo:ERROR withString:
                     [NSString stringWithFormat:@"ERROR: WHERE ARE WE??? We're closing a node for a test suite that hasn't been started [Expected: %@, Current: %@]. Ended: %@\nProblem line: %@",
                      testSuiteName,
                      node.testSuiteName,
                      node.ended ? @"YES" : @"NO",
                      line]];
                }
                self.current.endTime = date;
                self.current.ended = YES;
                self.current.passed = [kPassed isEqualToString:started];
                self.moveToParent = YES;
            }
        }
    }

    // Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' started.
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_STARTED options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 3) {
            logLine = NO;
            NSString *testCaseClass = [self adjustClassName:[line substringWithRange:[result rangeAtIndex:1]]];
            NSString *testCaseName = [line substringWithRange:[result rangeAtIndex:2]];
            BPTestCaseLogEntry *testCaseLogEntry = [[BPTestCaseLogEntry alloc] init];
            testCaseLogEntry.testCaseClass = testCaseClass;
            testCaseLogEntry.testCaseName = testCaseName;
            testCaseLogEntry.line = line;
            testCaseLogEntry.startTime = [NSDate date];
            [self.current addChild:testCaseLogEntry];
            self.currentTest = testCaseLogEntry;
            [self onTestCaseBeganWithName:testCaseName inClass:testCaseClass];
        }
    }

    // /Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:67: error: -[mntf_iosUITests.mntf_UISwiftTests testAdd] : XCTAssertTrue failed - This doesn't contain the string we're looking for!
    // /Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:75: error: -[mntf_iosUITests.mntf_UISwiftTests testGetName] : failed: caught "MyException", "My Reason"
    // /export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_7dee32c1fdb9facfff35737351eeab72cfa90126/Testing/VoyagerIntTestsLib/Shared/VoyagerIntTestCase.swift:172: error: -[VoyagerFeedIndividualPageTests.FeedEmptyFeedVariant1SplashTest testHighlightedDeepLinkEmptyFeedHidden] : The step timed out after 10.00 seconds: Waiting for notification "concurrent_dispatch_queue_finish"
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_FAILED options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 6) {
            logLine = YES; // We still want to log this line
            NSString *filename = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *lineNumber = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *testCaseClass = [self adjustClassName:[line substringWithRange:[result rangeAtIndex:3]]];
            NSString *testCaseName = [line substringWithRange:[result rangeAtIndex:4]];
            BOOL isError = NO;
            NSRange rangeOfFailure = [result rangeAtIndex:5];
            NSString *errorMessage = [line substringWithRange:rangeOfFailure];

            if (![errorMessage containsString:@"failed"]) {
                isError = YES;
            }

            BPTestCaseLogEntry *testCaseLogEntry = [self.current testCaseWithClass:testCaseClass andName:testCaseName];
            if (testCaseLogEntry) {
                testCaseLogEntry.filename = filename;
                testCaseLogEntry.lineNumber = [lineNumber integerValue];
                testCaseLogEntry.unexpected = isError;
                testCaseLogEntry.errorMessage = errorMessage;
            } else {
                [BPUtils printInfo:ERROR withString:
                 [NSString stringWithFormat:@"HOW DID WE GET AN ERROR THAT WASN'T PARSED? We received an error in a test case that wasn't started or did not parse properly.\nProblem line: %@",
                  line]];
            }
            // Do not set currentTest to nil so that we pick up any stack trace at the end of the log
        }
    }

    // fatal error: unexpectedly found nil while unwrapping an Optional value
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_CRASHED options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 2) {
            logLine = YES; // We still want to log this line
            NSString *errorMessage = [line substringWithRange:[result rangeAtIndex:1]];

            BPTestCaseLogEntry *testCaseLogEntry = self.currentTest;
            if (testCaseLogEntry) {
                testCaseLogEntry.filename = @"Unknown File";
                testCaseLogEntry.lineNumber = 0;
                testCaseLogEntry.unexpected = YES;
                testCaseLogEntry.errorMessage = errorMessage;
                // If we already reported the test as passing, we don't want to report it as a failure, but we want the log info
                if (!testCaseLogEntry.passed) {
                    [self onTestCaseFailedWithName:testCaseLogEntry.testCaseName inClass:testCaseLogEntry.testCaseClass
                                            inFile:testCaseLogEntry.filename onLineNumber:testCaseLogEntry.lineNumber
                                      wasException:testCaseLogEntry.unexpected];
                }
            }
            // Do not set currentTest to nil so that we pick up any stack trace at the end of the log
        }
    }

    // It is important that the check for TEST_CASE_CRASHED2 comes after TEST_CASE_CRASHED
    // This is because we want TEST_CASE_CRASHED to match first because it has better error information
    // and we'll only match TEST_CASE_CRASHED2 if self.currentTest is still not nil, meaning we haven't
    // already closed out the test.

    // stack trace for SIGNAL 11 (Segmentation fault: 11):
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_CRASHED2 options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 2) {
            logLine = YES; // We still want to log this line
            NSString *errorMessage = [line substringWithRange:[result rangeAtIndex:1]];

            BPTestCaseLogEntry *testCaseLogEntry = self.currentTest;
            if (testCaseLogEntry) {
                testCaseLogEntry.filename = @"Unknown File";
                testCaseLogEntry.lineNumber = 0;
                testCaseLogEntry.unexpected = YES;
                testCaseLogEntry.errorMessage = errorMessage;
                // If we already reported the test as passing, we don't want to report it as a failure, but we want the log info
                if (!testCaseLogEntry.passed) {
                    [self onTestCaseFailedWithName:testCaseLogEntry.testCaseName inClass:testCaseLogEntry.testCaseClass
                                            inFile:testCaseLogEntry.filename onLineNumber:testCaseLogEntry.lineNumber
                                      wasException:testCaseLogEntry.unexpected];
                }
            }
            // Do not set currentTest to nil so that we pick up any stack trace at the end of the log
        }
    }

    // *** Assertion failure in -[UICollectionView _dequeueReusableViewOfKind:withIdentifier:forIndexPath:viewCategory:], /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIKit_Sim/UIKit-3600.5.2/UICollectionView.m:4922
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_CRASHED3 options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 4) {
            logLine = YES;
            NSString *errorMessage = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *filename = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *lineNumber = [line substringWithRange:[result rangeAtIndex:3]];

            BPTestCaseLogEntry *testCaseLogEntry = self.currentTest;
            if (testCaseLogEntry) {
                testCaseLogEntry.filename = filename;
                testCaseLogEntry.lineNumber = [lineNumber integerValue];
                testCaseLogEntry.unexpected = YES;
                testCaseLogEntry.errorMessage = errorMessage;
                // If we already reported the test as passing, we don't want to report it as a failure, but we want the log info
                if (!testCaseLogEntry.passed) {
                    [self onTestCaseFailedWithName:testCaseLogEntry.testCaseName inClass:testCaseLogEntry.testCaseClass
                                            inFile:testCaseLogEntry.filename onLineNumber:testCaseLogEntry.lineNumber
                                      wasException:testCaseLogEntry.unexpected];
                }
            }
            // Do not set currentTest to nil so that we pick up any stack trace at the end of the log
        }
    }

    // /export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_b7eadfa63fdc85ff5143ed9ff580bb1a9ab7bc25/Testing/VoyagerIdentityTests/Me/Notifications/MeFeedAggregatePropCardTest.swift:421: error: -[VoyagerMeTests.MeFeedAggregatePropCardTest testExpandableAggregatePropCard] : Error Domain=com.LIMixture.MixtureProtocol.MixtureValidator Code=-101 "(null)" UserInfo={CapturedTrackingEvents=(
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_CRASHED4 options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 4) {
            logLine = YES;
            NSString *filename = [line substringWithRange:[result rangeAtIndex:1]];
            NSString *lineNumber = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *errorMessage = [line substringWithRange:[result rangeAtIndex:3]];

            BPTestCaseLogEntry *testCaseLogEntry = self.currentTest;
            if (testCaseLogEntry) {
                testCaseLogEntry.filename = filename;
                testCaseLogEntry.lineNumber = [lineNumber integerValue];
                testCaseLogEntry.unexpected = YES;
                testCaseLogEntry.errorMessage = errorMessage;
                // If we already reported the test as passing, we don't want to report it as a failure, but we want the log info
                if (!testCaseLogEntry.passed) {
                    [self onTestCaseFailedWithName:testCaseLogEntry.testCaseName inClass:testCaseLogEntry.testCaseClass
                                            inFile:testCaseLogEntry.filename onLineNumber:testCaseLogEntry.lineNumber
                                      wasException:testCaseLogEntry.unexpected];
                }
            }
            // Do not set currentTest to nil so that we pick up any stack trace at the end of the log
        }
    }

    // Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' passed (1.037 seconds).
    // Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' failed (1.037 seconds).
    regex = [NSRegularExpression regularExpressionWithPattern:TEST_CASE_PASSED options:0 error:nil];
    matches = [regex matchesInString:line options:0 range:lineRange];
    for (NSTextCheckingResult *result in matches) {
        if ([result numberOfRanges] == 5) {
            logLine = NO;
            NSString *testCaseClass = [self adjustClassName:[line substringWithRange:[result rangeAtIndex:1]]];
            NSString *testCaseName = [line substringWithRange:[result rangeAtIndex:2]];
            NSString *passed = [line substringWithRange:[result rangeAtIndex:3]];
            NSString *time = [line substringWithRange:[result rangeAtIndex:4]];

            BPTestCaseLogEntry *testCaseLogEntry = [self.current testCaseWithClass:testCaseClass andName:testCaseName];
            if (testCaseLogEntry) {
                testCaseLogEntry.totalTime = [time doubleValue];
                testCaseLogEntry.ended = YES;
                testCaseLogEntry.endTime = [NSDate date];
                testCaseLogEntry.passed = [kPassed isEqualToString:passed];
                if (testCaseLogEntry.passed) {
                    [self onTestCasePassedWithName:testCaseName inClass:testCaseClass reportedDuration:testCaseLogEntry.totalTime];
                } else {
                    [self onTestCaseFailedWithName:testCaseName inClass:testCaseClass
                                            inFile:testCaseLogEntry.filename onLineNumber:testCaseLogEntry.lineNumber
                                      wasException:testCaseLogEntry.unexpected];
                }
            } else {
                [BPUtils printInfo:ERROR withString:
                 [NSString stringWithFormat:@"HOW ON EARTH DID THIS HAPPEN? The test case passed but we failed to handle it properly\nProblem line: %@",
                  line]];
            }
            self.currentTest = nil;
        }
    }

    if (logLine) {
        BPLogEntry *logEntry;
        if (self.currentTest) {
            if (!self.currentTest.log) {
                self.currentTest.log = @"";
            }
            logEntry = self.currentTest;
        } else {
            if (!self.current.log) {
                self.current.log = @"";
            }
            logEntry = self.current;
        }
        logEntry.log = [logEntry.log stringByAppendingString:line];
        logEntry.log = [logEntry.log stringByAppendingString:@"\n"];
    }
}

- (NSString *)adjustClassName:(NSString *)inClassName {
    if ([inClassName containsString:@"."]) {
        return [inClassName componentsSeparatedByString:@"."].lastObject;
    }
    return inClassName;
}

- (void)onTestAbortedWithName:(NSString *)testName inClass:(NSString *)testClass errorMessage:(NSString *)message {
    BPTestCaseLogEntry *testCaseLogEntry = [self.current testCaseWithClass:testClass andName:testName];
    if (testCaseLogEntry) {
        if (!testCaseLogEntry.errorMessage || ![testCaseLogEntry.errorMessage length]) {
            testCaseLogEntry.errorMessage = message;
        }
        testCaseLogEntry.passed = NO;
        testCaseLogEntry.unexpected = YES;
    }
    self.aborted = YES;
}

- (void)completed {
    if (self.aborted) {
        [self closeOffAllSuites];
        return; // We don't want the normal calculations if the tests were aborted because we're just going to overwrite the log anyway.
    }
    [self calculateTotals];
}

- (void)completedFinalRun {
    // On the final run, we should calculate totals if we previously didn't
    // due to a crash/abort
    if (self.aborted) {
        [self calculateTotals];
    }
}

- (void)cleanup {
    [[BPTreeAssembler sharedInstance] reset];
}

- (void)calculateTotals {
    [self calculateTotalsFor:self.root];
    [self checkForDiscrepancies:self.root];
}

// This method is called when tests have been aborted and we need to forcefully "close" the open test suites so that they will log correctly.
- (void)closeOffAllSuites {
    [self closeOffAllSuitesFor:self.root];
}
- (void)closeOffAllSuitesFor:(BPLogEntry *)logEntry {
    if (logEntry != self.root && !logEntry.ended) {
        logEntry.ended = YES;
        logEntry.endTime = [NSDate date];
        logEntry.totalTime = [logEntry.endTime timeIntervalSinceDate:logEntry.startTime]; // Synthesize the total time
    }
    if ([logEntry isKindOfClass:[BPTestSuiteLogEntry class]]) {
        BPTestSuiteLogEntry *suiteChild = (BPTestSuiteLogEntry *)logEntry;
        for (BPLogEntry *child in suiteChild.children) {
                [self closeOffAllSuitesFor:child];
        }
    }
}

- (void)calculateTotalsFor:(BPTestSuiteLogEntry *)logEntry {
    for (BPLogEntry *child in logEntry.children) {
        if ([child isKindOfClass:[BPTestSuiteLogEntry class]]) {
            BPTestSuiteLogEntry *suiteChild = (BPTestSuiteLogEntry *)child;
            [self calculateTotalsFor:suiteChild];
            logEntry.numberOfTests += suiteChild.numberOfTests;
            logEntry.numberOfFailures += suiteChild.numberOfFailures;
            logEntry.numberOfUnexpected += suiteChild.numberOfUnexpected;
            if (logEntry.reportedTotalTime > 0) {
                logEntry.totalTime = logEntry.reportedTotalTime;
            } else {
                logEntry.totalTime += suiteChild.totalTime;
            }
        } else if([child isKindOfClass:[BPTestCaseLogEntry class]]) {
            BPTestCaseLogEntry *caseChild = (BPTestCaseLogEntry *)child;
            logEntry.numberOfTests += 1;
            logEntry.numberOfFailures += caseChild.passed ? 0 : 1;
            logEntry.numberOfUnexpected += caseChild.unexpected ? 1 : 0;
            if (logEntry.reportedTotalTime > 0) {
                logEntry.totalTime = logEntry.reportedTotalTime;
            } else {
                logEntry.totalTime += caseChild.totalTime;
            }
        }
    }
}

- (void)checkForDiscrepancies:(BPTestSuiteLogEntry *)logEntry {
    if (logEntry.numberOfTests != logEntry.reportedNumberOfTests) {
        [BPUtils printInfo:DEBUGINFO withString:@"[%s] Mismatch numberOfTests calculated (%lu) vs reported (%lu)", [logEntry.testSuiteName UTF8String], logEntry.numberOfTests, logEntry.reportedNumberOfTests];
    }
    if (logEntry.numberOfFailures != logEntry.reportedNumberOfFailures) {
        [BPUtils printInfo:DEBUGINFO withString:@"[%s] Mismatch numberOfFailures calculated (%lu) vs reported (%lu)", [logEntry.testSuiteName UTF8String], logEntry.numberOfFailures, logEntry.reportedNumberOfFailures];
    }
    if (logEntry.numberOfUnexpected != logEntry.reportedNumberOfUnexpected) {
        [BPUtils printInfo:DEBUGINFO withString:@"[%s] Mismatch numberOfUnexpected calculated (%lu) vs reported (%lu)", [logEntry.testSuiteName UTF8String], logEntry.numberOfUnexpected, logEntry.reportedNumberOfUnexpected];
    }
    if (logEntry.totalTime != logEntry.reportedTotalTime) {
        [BPUtils printInfo:DEBUGINFO withString:@"[%s] Mismatch totalTime calculated (%f) vs reported (%f)", [logEntry.testSuiteName UTF8String], logEntry.totalTime, logEntry.reportedTotalTime];
    }
    for (BPLogEntry *child in logEntry.children) {
        if ([child isKindOfClass:[BPTestSuiteLogEntry class]]) {
            BPTestSuiteLogEntry *suiteChild = (BPTestSuiteLogEntry *)child;
            [self checkForDiscrepancies:suiteChild];
        }
    }
}

- (NSString *)generateLog:(id<BPReporter>)reporter {
    return [reporter generate:self.root] ?: [NSString stringWithFormat:@"NO LOG: %@", [reporter class]];
}

- (void)setDelegate:(id<BPExecutionPhaseProtocol>)delegate {
    _delegate = delegate;
    [self setMonitorCallback:self];
}

#pragma BPExecutionPhaseProtocol

- (void)setMonitorCallback:(id<BPMonitorCallbackProtocol>)callback {
    [self.delegate setMonitorCallback:callback];
}

- (void)onAllTestsBegan {
    if (self.testsBegan) {
        return;
    }

    [self.delegate onAllTestsBegan];
    self.testsBegan = YES;
}

- (void)onAllTestsEnded {
    if (!self.testsBegan) {
        return;
    }

    [self.delegate onAllTestsEnded];
    self.testsBegan = NO;
}

- (void)onTestSuiteBegan:(NSString *)testSuiteName onDate:(NSDate *)startDate isRoot:(BOOL)isRoot {
    [self onAllTestsBegan];
    [self.delegate onTestSuiteBegan:testSuiteName onDate:startDate isRoot:isRoot];
}

- (void)onTestSuiteEnded:(NSString *)testSuiteName
                fromDate:(NSDate *)startDate
                  toDate:(NSDate *)endDate
                  passed:(BOOL)wholeSuitePassed
               withTotal:(NSUInteger)totalTestCount
                  failed:(NSUInteger)failedCount
              unexpected:(NSUInteger)unexpectedFailures
                  isRoot:(BOOL)isRoot {
    [self.delegate onTestSuiteEnded:testSuiteName
                           fromDate:startDate
                             toDate:endDate
                             passed:wholeSuitePassed
                          withTotal:totalTestCount
                             failed:failedCount
                         unexpected:unexpectedFailures
                             isRoot:isRoot];
    if (testSuiteName == self.root.testSuiteName || testSuiteName == self.currentRootName) {
        [self onAllTestsEnded];
    }
}

- (void)onTestCaseBeganWithName:(NSString *)testName inClass:(NSString *)testClass {
    [self.delegate onTestCaseBeganWithName:testName inClass:testClass];
}

- (void)onTestCasePassedWithName:(NSString *)testName inClass:(NSString *)testClass reportedDuration:(NSTimeInterval)duration {
    [self.delegate onTestCasePassedWithName:testName inClass:testClass reportedDuration:duration];
}

- (void)onTestCaseFailedWithName:(NSString *)testName inClass:(NSString *)testClass
                          inFile:(NSString *)filePath onLineNumber:(NSUInteger)lineNumber wasException:(BOOL)wasException {
    [self.delegate onTestCaseFailedWithName:testName inClass:testClass inFile:filePath onLineNumber:lineNumber wasException:wasException];
}

- (void)onOutputReceived:(NSString *)output {
    [self.delegate onOutputReceived:output];
}

@end
