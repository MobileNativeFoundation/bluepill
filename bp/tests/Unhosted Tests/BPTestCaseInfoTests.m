//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import <BPTestInspector/Internal/BPTestCaseInfo+Internal.h>

@interface BPTestCaseInfoTests : XCTestCase

@end

@implementation BPTestCaseInfoTests

- (void)testArchiving {
    // Mock data
    BPTestCaseInfo *info1 = [[BPTestCaseInfo alloc] initWithClassName:@"Class" methodName:@"Method1"];
    BPTestCaseInfo *info2 = [[BPTestCaseInfo alloc] initWithClassName:@"Class" methodName:@"Method2"];
    BPTestCaseInfo *info3 = [[BPTestCaseInfo alloc] initWithClassName:@"Class" methodName:@"Method3"];
    NSArray<BPTestCaseInfo *> *testCasesIn = @[info1, info2, info3];
    // Archive
    NSError *error;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:testCasesIn requiringSecureCoding:NO error:&error];
    // Unarchive
    NSArray<BPTestCaseInfo *> *testCasesOut = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:BPTestCaseInfo.class
                                                                                        fromData:data
                                                                                           error:&error];
    // Validate
    XCTAssertNotNil(testCasesOut);
    XCTAssertEqual(testCasesIn.count, testCasesOut.count);
    for (int i = 0; i < testCasesIn.count; i++) {
        XCTAssertEqualObjects(testCasesIn[i], testCasesOut[i]);
    }
}

@end
