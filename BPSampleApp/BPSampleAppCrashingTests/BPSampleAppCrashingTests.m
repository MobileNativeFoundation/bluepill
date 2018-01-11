//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#include "SigHandler.h"

@interface BPSampleAppCrashingTests : XCTestCase

@end

@implementation BPSampleAppCrashingTests

- (void)setUp {
    [super setUp];
    initsighandler();
    // Put setup code here. This method is called before the invocation of each test method in the class.

}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAppCrash0 {
    XCTAssert(YES);
}

- (void)testAppCrash1 {
    int *pointer = nil;
    NSInteger counter = 1;
    NSString* testCounter = [[[NSProcessInfo processInfo]environment]objectForKey:@"_BP_TEST_ATTEMPT_NUMBER"];
    if (testCounter != nil) {
        counter = [testCounter integerValue];
    }
    if (counter == 1) {
        // crash the first time
        *pointer = 1;
    } else {
        // pass the second time
        XCTAssert(YES);
    }
}

- (void)testAppCrash2 {
    XCTAssert(YES);
}

@end
