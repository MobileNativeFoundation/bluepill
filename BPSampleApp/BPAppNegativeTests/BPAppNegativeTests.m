//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

@interface BPAppNegativeTests : XCTestCase

@end

@implementation BPAppNegativeTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

//- (void)testNilPointerCrash {
//    int *pointer = nil;
//    *pointer = 1;
//    printf("%d", *pointer);
//}

//- (void)testHangsForever {
//    while(YES){}
//}

- (void)testAssertFailure {
    XCTAssert(NO, @"THIS_TEST_SHOULD_FAIL");
}

- (void)testAssertTrue {
    XCTAssert(YES, @"THIS_TEST_SHOULD_PASS");
}

- (void)testRaiseException {
    [NSException raise:@"Invalid foo value" format:@"foo of %d is invalid", 1];
}

- (NSString *)randomStringOfLength: (NSInteger)length {
    NSString *alphabet  = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:length];
    for (NSUInteger i = 0U; i < length; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return s;
}

- (void)testBPDoesNotHangWithBigOutput {
    // we want to exceed the internal buffer of a named pipe
    NSMutableArray *lines = [[NSMutableArray alloc] init];
    for (int i = 0; i < 1024 ; ++i) {
        [lines addObject:[self randomStringOfLength:128]];
    }
    NSString *all = [NSString stringWithFormat:@"%@\n", [lines componentsJoinedByString:@"\n"]];
    // we want a single write that puts all the data out
    XCTAssert(false, @"%@", all);
}


@end
