//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPTreeParser.h"
#import "BPUtils.h"

@interface RegexTests : XCTestCase

@end

@implementation RegexTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
}

- (void)testStartOfSuite {
    NSString *line = @"Test Suite 'mntf_UISwiftTests' started at 2016-10-07 12:52:05.091";
    [self performTestWithString:line regex:TEST_SUITE_START matches:@[@"mntf_UISwiftTests", @"started", @"2016-10-07 12:52:05.091"]];
}

- (void)testSuitePassed {
    NSString *line = @"Test Suite 'Debug-iphonesimulator' passed at 2016-10-07 12:52:05.091.";
    [self performTestWithString:line regex:TEST_SUITE_START matches:@[@"Debug-iphonesimulator", @"passed", @"2016-10-07 12:52:05.091"]];
}

- (void)testSuiteFailed {
    NSString *line = @"Test Suite 'mntf_UISwiftTests' failed at 2016-10-07 12:52:08.297.";
    [self performTestWithString:line regex:TEST_SUITE_START matches:@[@"mntf_UISwiftTests", @"failed", @"2016-10-07 12:52:08.297"]];
}

- (void)testSuiteEnded {
    NSString *line = @"Executed 9 tests, with 2 failures (1 unexpected) in 2.980 (3.206) seconds";
    [self performTestWithString:line regex:TEST_SUITE_ENDED matches:@[@"9", @"2", @"1", @"2.980", @"3.206"]];
}

- (void)testCaseStarted {
    NSString *line = @"Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' started.";
    [self performTestWithString:line regex:TEST_CASE_STARTED matches:@[@"mntf_iosUITests.mntf_UISwiftTests", @"testWaitForCheckpoint"]];
}

- (void)testCasePassed {
    NSString *line = @"Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' passed (1.037 seconds).";
    [self performTestWithString:line regex:TEST_CASE_PASSED matches:@[@"mntf_iosUITests.mntf_UISwiftTests", @"testWaitForCheckpoint", @"passed", @"1.037"]];
}

- (void)testCaseFailure {
    NSString *line = @"/Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:67: error: -[mntf_iosUITests.mntf_UISwiftTests testAdd] : XCTAssertTrue failed - This doesn't contain the string we're looking for!";
    NSString *regexStr = TEST_CASE_FAILED;
    NSArray *values = @[
                        @"/Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift",
                        @"67",
                        @"mntf_iosUITests.mntf_UISwiftTests",
                        @"testAdd",
                        @"XCTAssertTrue failed - This doesn't contain the string we're looking for!"
                        ];

    NSRange lineRange = NSMakeRange(0, [line length]);

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSArray *matches = [regex matchesInString:line options:0 range:lineRange];
    XCTAssert([matches count] > 0);
    for (NSTextCheckingResult *result in matches) {
        XCTAssert([result numberOfRanges] == 6, @"numberOfRanges is %lu, values count is %lu", [result numberOfRanges], [values count]);
        for (NSInteger i = 1; i < [result numberOfRanges]; ++i) {
            NSRange range = [result rangeAtIndex:i];
            if (range.location != NSNotFound) {
                NSString *match = [line substringWithRange:range];
                 NSLog(@"Check %@ == %@", match, values[i-1]);
                XCTAssert([match isEqualToString:values[i-1]], @"%@ not equal to %@", match, values[i-1]);
            }
        }
    }
}

- (void)testCaseError {
    NSString *line = @"/Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:67: error: -[mntf_iosUITests.mntf_UISwiftTests testAdd] : XCTAssertTrue failed - This doesn't contain the string we're looking for!";
    line = @"/export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_7dee32c1fdb9facfff35737351eeab72cfa90126/Testing/VoyagerIntTestsLib/Shared/VoyagerIntTestCase.swift:172: error: -[VoyagerFeedIndividualPageTests.FeedEmptyFeedVariant1SplashTest testHighlightedDeepLinkEmptyFeedHidden] : The step timed out after 10.00 seconds: Waiting for notification \"concurrent_dispatch_queue_finish\"";
    NSString *regexStr = TEST_CASE_FAILED;
    NSArray *values = @[
                        @"/export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_7dee32c1fdb9facfff35737351eeab72cfa90126/Testing/VoyagerIntTestsLib/Shared/VoyagerIntTestCase.swift",
                        @"172",
                        @"VoyagerFeedIndividualPageTests.FeedEmptyFeedVariant1SplashTest",
                        @"testHighlightedDeepLinkEmptyFeedHidden",
                        @"The step timed out after 10.00 seconds: Waiting for notification \"concurrent_dispatch_queue_finish\""
                        ];

    NSRange lineRange = NSMakeRange(0, [line length]);

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSArray *matches = [regex matchesInString:line options:0 range:lineRange];
    XCTAssert([matches count] > 0);
    for (NSTextCheckingResult *result in matches) {
        XCTAssert([result numberOfRanges] == 6, @"numberOfRanges is %lu, values count is %lu", [result numberOfRanges], [values count]);
        for (NSInteger i = 1; i < [result numberOfRanges]; ++i) {
            NSRange range = [result rangeAtIndex:i];
            if (range.location != NSNotFound) {
                NSString *match = [line substringWithRange:range];
                NSLog(@"Check %@ == %@", match, values[i-1]);
                XCTAssert([match isEqualToString:values[i-1]], @"%@ not equal to %@", match, values[i-1]);
            }
        }
    }
}

- (void)testCaseExceptionFailure {
    NSString *line = @"/Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:75: error: -[mntf_iosUITests.mntf_UISwiftTests testGetName] : failed: caught \"MyException\", \"My Reason\"";
    NSString *regexStr = TEST_CASE_FAILED;
    NSArray *values = @[
                        @"/Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift",
                        @"75",
                        @"mntf_iosUITests.mntf_UISwiftTests",
                        @"testGetName",
                        @"failed: caught \"MyException\", \"My Reason\""
                        ];

    NSRange lineRange = NSMakeRange(0, [line length]);

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSArray *matches = [regex matchesInString:line options:0 range:lineRange];
    XCTAssert([matches count] > 0);
    for (NSTextCheckingResult *result in matches) {
        XCTAssert([result numberOfRanges] == 6, @"numberOfRanges is %lu, values count is %lu", [result numberOfRanges], [values count]);
        int n = 0;
        for (NSInteger i = 1; i < [result numberOfRanges]; ++i) {
            NSRange range = [result rangeAtIndex:i];
            if (range.location != NSNotFound) {
                NSString *match = [line substringWithRange:range];
                // NSLog(@"Check %@ == %@", match, values[i-1]);
                XCTAssert([match isEqualToString:values[n]], @"%@ not equal to %@", match, values[n]);
                n++;
            }
        }
    }
}

- (void)performTestWithString:(NSString *)line regex:(NSString *)regexStr matches:(NSArray *)values {
    NSRange lineRange = NSMakeRange(0, [line length]);

    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:0 error:nil];
    NSArray *matches = [regex matchesInString:line options:0 range:lineRange];
    XCTAssert([matches count] > 0);
    for (NSTextCheckingResult *result in matches) {
        XCTAssert([result numberOfRanges] == ([values count] + 1), @"numberOfRanges is %lu, values count is %lu", [result numberOfRanges], [values count]);
        for (NSInteger i = 1; i < [result numberOfRanges]; ++i) {
            NSString *match = [line substringWithRange:[result rangeAtIndex:i]];
            XCTAssert([match isEqualToString:values[i-1]], @"%@ not equal to %@", match, values[i-1]);
        }
    }
}

@end
