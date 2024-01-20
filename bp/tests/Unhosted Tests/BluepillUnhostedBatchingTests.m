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
#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "BPUtils.h"
#import "BPTestUtils.h"

@interface BluepillUnhostedBatchingTests : BPIntTestCase
@end

@implementation BluepillUnhostedBatchingTests

- (void)setUp {
    [super setUp];
    self.config = [BPTestUtils makeUnhostedTestConfiguration];
    self.config.numSims = @1;
    self.config.stuckTimeout = @3;
    self.config.testBundlePath = [BPTestHelper passingLogicTestBundlePath];
    
    NSString *tempDir = NSTemporaryDirectory();
    NSError *error;
    self.config.outputDirectory = [BPUtils mkdtemp:[NSString stringWithFormat:@"%@/TestLogsTempDir", tempDir] withError:&error];
}

- (void)testAllTests {
    // This is redundant but made explicit here for test clarity
    self.config.testCasesToRun = nil;
    self.config.testCasesToSkip = nil;

    // Run Tests
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAllTestsPassed];

    // Check that test is started in both sets of logs.
    for (NSString *testCase in [BluepillUnhostedBatchingTests allTestCases]) {
        [BPTestUtils checkIfTestCase:testCase bundleName:@"BPPassingLogicTests" wasRunInLog:[self.config.outputDirectory stringByAppendingPathComponent:@"1-simulator.log"]];
    }
}

- (void)testOptInToObjcTests {
    [self validateOptInToTests:@[
        @"BPPassingLogicTests/testPassingLogicTest2",
        @"BPPassingLogicTests/testPassingLogicTest3",
    ]];
}

- (void)testOptInToSwiftTests {
    [self validateOptInToTests:@[
        @"SwiftLogicTests/testPassingLogicTest1()",
    ]];
}

- (void)testOptOutOfObjcTests {
    [self validateOptOutOfTests:@[
        @"BPPassingLogicTests/testPassingLogicTest2",
        @"BPPassingLogicTests/testPassingLogicTest3",
    ]];
}

- (void)testOptOutOfSwiftTests {
    [self validateOptOutOfTests:@[
        @"SwiftLogicTests/testPassingLogicTest3()",
    ]];
}

#pragma mark - Helpers

- (void)validateOptInToTests:(NSArray<NSString *> *)tests {
    self.config.testCasesToRun = tests;
    [self validateExactlyTheseTestsAreExecuted:tests];
}

- (void)validateOptOutOfTests:(NSArray<NSString *> *)tests {
    self.config.testCasesToSkip = tests;
    NSArray<NSString *> *expectedTests = [BluepillUnhostedBatchingTests allTestsExcept:tests];
    [self validateExactlyTheseTestsAreExecuted:expectedTests];
}

- (void)validateExactlyTheseTestsAreExecuted:(NSArray<NSString *> *)tests {
    // Run Tests
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    [BPTestUtils assertExitStatus:exitCode matchesExpected:BPExitStatusAllTestsPassed];

    // Check that exclusively these tests were run.
    for (NSString *testCase in tests) {
        NSLog(@"testCase: %@", testCase);
        XCTAssert([BPTestUtils checkIfTestCase:testCase bundleName:@"BPPassingLogicTests" wasRunInLog:[self.config.outputDirectory stringByAppendingPathComponent:@"1-simulator.log"]]);
    }
    
    // Check that "skipped" tests are not run.
    for (NSString *testCase in [BluepillUnhostedBatchingTests allTestsExcept:tests]) {
        XCTAssertFalse([BPTestUtils checkIfTestCase:testCase bundleName:@"BPPassingLogicTests" wasRunInLog:[self.config.outputDirectory stringByAppendingPathComponent:@"1-simulator.log"]]);
    }
}

+ (NSArray<NSString *> *)allTestCases {
    return @[
        @"BPPassingLogicTests/testPassingLogicTest1",
        @"BPPassingLogicTests/testPassingLogicTest2",
        @"BPPassingLogicTests/testPassingLogicTest3",
        @"BPPassingLogicTests/testPassingLogicTest4",
        @"SwiftLogicTests/testPassingLogicTest1()",
        @"SwiftLogicTests/testPassingLogicTest2()",
        @"SwiftLogicTests/testPassingLogicTest3()",
    ];
}

+ (NSArray<NSString *> *)allTestsExcept:(NSArray<NSString *> *)omittedTests {
    NSMutableArray<NSString *> *mutableTests = [[self allTestCases] mutableCopy];
    [mutableTests removeObjectsInArray:omittedTests];
    return [mutableTests copy];
}

@end
