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

#import "BPIntTestCase.h"
#import "BPConfiguration.h"
#import "BPTestHelper.h"
#import "BPTestUtils.h"
#import "BPUtils.h"
#import "SimDeviceType.h"
#import "SimRuntime.h"
#import "SimServiceContext.h"

@implementation BPIntTestCase

- (void)setUp {
    [super setUp];

    self.continueAfterFailure = NO;

    [BPUtils quietMode:[BPUtils isBuildScript]];
    [BPUtils enableDebugOutput:YES];
}

@end
