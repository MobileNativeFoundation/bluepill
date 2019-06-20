//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

@interface BPSampleAppCrashingTests : XCTestCase

@end

@implementation BPSampleAppCrashingTests

NSString *attemptFromSimulatorVersionInfo(NSString *simulatorVersionInfo) {
    // simulatorVersionInfo is something like
    // CoreSimulator 587.35 - Device: BP93497-2-2 (7AB3D528-5473-401A-B23E-2E2E86C73861) - Runtime: iOS 12.2 (16E226) - DeviceType: iPhone 7
    NSArray<NSString *> *parts = [simulatorVersionInfo componentsSeparatedByString:@" - "];
    NSString *deviceString = parts[1];
    // Device: BP93497-2-2 (7AB3D528-5473-401A-B23E-2E2E86C73861)
    parts = [deviceString componentsSeparatedByString:@" "];
    NSString *device = parts[1];
    // BP93497-2-2
    parts = [device componentsSeparatedByString:@"-"];
    NSString *attempt = parts[1];
    return attempt;

}

- (void)setUp {
    [super setUp];
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
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *simulatorVersionInfo = [env objectForKey:@"SIMULATOR_VERSION_INFO"];
    NSString *attempt = attemptFromSimulatorVersionInfo(simulatorVersionInfo);
    NSString *crashOnAttempt = [env objectForKey:@"_BP_TEST_CRASH_ON_ATTEMPT"];

    NSLog(@"Attempt: %@ Crash requested on %@", attempt, crashOnAttempt);
    if (crashOnAttempt && crashOnAttempt != attempt) {
        NSLog(@"not crashing");
        return;
    }
    NSLog(@"crashing");
    // ok, let's crash and burn
    int *pointer = nil;
    *pointer = 1;
}

- (void)testAppCrash2 {
    XCTAssert(YES);
}

@end
