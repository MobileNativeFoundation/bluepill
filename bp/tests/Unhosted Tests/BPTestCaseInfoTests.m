//
//  BPTestCaseInfoTests.m
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 7/16/23.
//  Copyright © 2023 Facebook. All rights reserved.
//

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
