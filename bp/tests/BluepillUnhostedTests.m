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
#import "BPSimulator.h"
#import "BPTestUtils.h"

#import "SimDevice.h"

/**
 * This test suite is the integration tests to make sure Bluepill instance is working properly
 * - Exit code testing
 * - Report validation
 */
@interface BluepillUnhostedTests : BPIntTestCase
@end

@implementation BluepillUnhostedTests

- (void)setUp {
    [super setUp];
    self.config = [BPTestUtils makeUnhostedTestConfiguration];
    self.config.numSims = @1;
}

- (void)testLogicTests {
    NSString *testBundlePath = [BPTestHelper logicTestBundlePath];
    self.config.testBundlePath = testBundlePath;
    self.config.stuckTimeout = @3;
    BPExitStatus exitCode = [[[Bluepill alloc ] initWithConfiguration:self.config] run];
    XCTAssert(exitCode == BPExitStatusAllTestsPassed,
              @"Expected: %@ Got: %@",
              [BPExitStatusHelper stringFromExitStatus:BPExitStatusAllTestsPassed],
              [BPExitStatusHelper stringFromExitStatus:exitCode]);
}


@end
