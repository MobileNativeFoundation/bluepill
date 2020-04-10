//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

@interface BPSampleAppHangingTests : XCTestCase

@end

@implementation BPSampleAppHangingTests

-(long)attemptFromSimulatorVersionInfo:(NSString *)simulatorVersionInfo {
    // simulatorVersionInfo is something like
    // CoreSimulator 587.35 - Device: BP93497-2-2 (7AB3D528-5473-401A-B23E-2E2E86C73861) - Runtime: iOS 12.2 (16E226) - DeviceType: iPhone 7
    NSLog(@"Dissecting version info %@ to extra attempt number.", simulatorVersionInfo);
    NSArray<NSString *> *parts = [simulatorVersionInfo componentsSeparatedByString:@" - "];
    NSString *deviceString = parts[1];
    // Device: BP93497-2-2 (7AB3D528-5473-401A-B23E-2E2E86C73861)
    parts = [deviceString componentsSeparatedByString:@" "];
    NSString *device = parts[1];
    // BP93497-2-2
    parts = [device componentsSeparatedByString:@"-"];
    NSString *attempt = parts[1];
    return [attempt longLongValue];
}

-(void)extractPlanAndExecuteActions:(int)index {
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *simulatorVersionInfo = [env objectForKey:@"SIMULATOR_VERSION_INFO"];
    long attempt = [self attemptFromSimulatorVersionInfo:simulatorVersionInfo];
    NSString *executionPlan = [env objectForKey:@"_BP_TEST_EXECUTION_PLAN"];
    if (!executionPlan) {
        NSLog(@"No execution plan found in attempt#%ld. Failing the test.", attempt);
        XCTAssert(NO);
        return;
    }
    NSLog(@"Received execution plan %@ on attempt#%ld for this test.", executionPlan, attempt);
    NSArray *setsOfPlans = [executionPlan componentsSeparatedByString:@";"];
    if (index >= [setsOfPlans count]) {
        NSLog(@"Not enough plans for test#%d in execution plan: '%@'.", index, executionPlan);
        XCTAssert(YES);
        return;
    }
    NSString *currentPlan = setsOfPlans[index];
    currentPlan = [currentPlan stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *array = [currentPlan componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (attempt > [array count]) {
        NSLog(@"Passing on attempt#%ld, by default, as there is no action defined in the execution plan", (long)attempt);
        XCTAssert(YES);
        return;
    }
    NSString *action = array[attempt - 1];
    if ([action isEqualToString:@"TIMEOUT"]) {
        NSLog(@"Entering into an infinite loop on attempt#%ld to timeout as per the execution plan", (long)attempt);
        while(1) {
        }
        return;
    } else if ([action isEqualToString:@"PASS"]) {
        NSLog(@"Passing on attempt#%ld based on execution plan", (long)attempt);
        XCTAssert(YES);
        return;
    } else if ([action isEqualToString:@"FAIL"]) {
        NSLog(@"Failing on attempt#%ld based on execution plan", (long)attempt);
        XCTAssert(NO);
        return;
    } else if ([action isEqualToString:@"CRASH"]) {
        NSLog(@"Crashing on attempt#%ld based on execution plan", (long)attempt);
        // ok, let's crash and burn
        int *pointer = nil;
        *pointer = 1;
        return;
    }
    NSLog(@"Failing on attempt#%ld as an unidentified action is encountered in the execution plan", (long)attempt);
    XCTAssert(NO);
    return;
}

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testASimpleTest {
    XCTAssert(YES);
}

- (void)testBasedOnExecutionPlan {
    [self extractPlanAndExecuteActions:0];
}

- (void)testCaseFinal {
    XCTAssert(YES);
}

- (void)testDoubleBasedOnExecutionPlan {
    [self extractPlanAndExecuteActions:1];
}

- (void)testEndFinal {
    XCTAssert(YES);
}

@end
