//
//  BPSampleAppTestTimeoutTests.m
//  BPSampleAppTestTimeoutTests
//
//  Created by Xiaobo Zhang on 2/2/18.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>

@interface BPSampleAppTestTimeoutTests : XCTestCase
@end

@implementation BPSampleAppTestTimeoutTests
- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// This test testcase timetout. App hang timeout is going through a different code path
- (void)testCaseTimeout {
    int timer = 0;
    XCTAssert(NO);
//    while (timer++ < 100) {
//        NSLog(@"keep producing output until test case timeout");
//        [NSThread sleepForTimeInterval:2.0];
//    }
}

//- (void)testAppCrash1 {
//    int *pointer = nil;
//    NSInteger counter = 1;
//    NSString* testCounter = [[[NSProcessInfo processInfo]environment]objectForKey:@"_BP_TEST_ATTEMPT_NUMBER"];
//    if (testCounter != nil) {
//        counter = [testCounter integerValue];
//    }
//    if (counter == 1) {
//        // crash the first time
//        *pointer = 1;
//    }
//}

- (void)testExample2 {
    NSLog(@"hi2");
    XCTAssert(YES);
}


@end
