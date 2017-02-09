//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>

@interface BPSampleAppFatalErrorTests : XCTestCase

@end

@implementation BPSampleAppFatalErrorTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)test0 {
    XCTAssert(YES);
}

- (void)testCrashAppError {
    int i[5];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warray-bounds"
    i[6] = 10;
#pragma clang diagnostic pop
}

- (void)testCZ {
    XCTAssert(YES);
}

@end
