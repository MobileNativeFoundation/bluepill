//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPWaitTimer.h"
#import "BPUtils.h"

@interface WaitTimerTests : XCTestCase

@end

@implementation WaitTimerTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testTimerHits {
    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:0.5];

    // Test with start BEFORE the onTimeout definition
    [timer start];

    __block BOOL timerHit = NO;
    timer.onTimeout = ^{
        timerHit = YES;
    };
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 1.0, NO);
    XCTAssert(timerHit, "Did not hit the onTimeout method");
}

- (void)testTimerDoesNotHit {
    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:2.0];

    // Test with start BEFORE the onTimeout definition
    [timer start];

    __block BOOL timerHit = NO;
    timer.onTimeout = ^{
        timerHit = YES;
    };
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO);
    XCTAssert(timerHit == false, "Hit the onTimeout method when we should not have");
}

@end
