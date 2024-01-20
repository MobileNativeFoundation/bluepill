//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

@interface BPLogicTests : XCTestCase

@end

@implementation BPLogicTests

- (void)testPassingLogicTest1 {
    XCTAssert(YES);
}

- (void)testPassingLogicTest2 {
    XCTAssert(YES);
}

- (void)testFailingLogicTest {
    XCTAssert(NO);
}

/*
 This failure should be recognized as a test failure
 in the xctest logs, and testing should be able to continue.
 */
- (void)testCrashTestCaseLogicTest {
    NSLog(@"BPLogicTests - FORCING TEST EXECUTION CRASH.");
    NSObject *unused = @[][666];
}

/*
 This failure will cause the whole execution to fail, and
 requires separate special handling.
 */
- (void)testCrashExecutionLogicTest {
    NSLog(@"BPLogicTests - FORCING SIMULATOR CRASH.");
    char *p = NULL;
    strcpy(p, "I know this will crash my app");
}

- (void)testStuckLogicTest {
    NSLog(@"BPLogicTests - FORCING TEST TIMEOUT");
    while(1) {
        sleep(10);
    }
}

- (void)testSlowLogicTest {
    NSLog(@"BPLogicTests - FORCING TEST TIMEOUT");
    while(1) {
        NSLog(@"Look I'm trying, but to no avail!");
        sleep(1);
    }
}

// The below should not timeout when run in succession

- (void)testOneSecondTest1 {
    sleep(1);
    XCTAssert(YES);
}

- (void)testOneSecondTest2 {
    sleep(1);
    XCTAssert(YES);
}

- (void)testOneSecondTest3 {
    sleep(1);
    XCTAssert(YES);
}

@end
