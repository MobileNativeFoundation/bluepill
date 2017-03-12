//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPUtils.h"

@interface BPUtilsTests : XCTestCase

@end

@implementation BPUtilsTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testBuildArgsAndEnvironmentWithPath {
    NSString *path = @"testScheme.xcscheme";
    path = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
    NSDictionary *dictionary = [BPUtils buildArgsAndEnvironmentWith:path];
    NSDictionary *expectedDictionary = @{
                                         @"args" : @[
                                                 @"-com.linkedin.mntf-ios.EnvironmentAnimationSpeed",
                                                 @"10000",
                                                 @"-com.linkedin.kif.EnvironmentUseAnimation",
                                                 @"false",
                                                 @"-com.linkedin.kif.EnvironmentSpeed",
                                                 @"10",
                                                 @"-com.linkedin.mntf-ios.EnvironmentLiveTestsEnabled",
                                                 @"false",
                                                 @"-mntf.validateLiveEvents",
                                                 @"true",
                                                 @"-NSTreatUnknownArgumentsAsOpen",
                                                 @"NO",
                                                 @"-ApplePersistenceIgnoreState",
                                                 @"YES"
                                                 ],
                                         @"env" : @{
                                                 @"MNTF_SCREENSHOTS" : @"$(PROJECT_DIR)/build/outputs/tests_artifacts",
                                                 @"MNTF_SCREENSHOTS_BASELINE" : @"$(PROJECT_DIR)/mntf-iosUITests/Screenshots/Baseline",
                                                 @"MNTF_SCREENSHOTS_BASELINE_REAL" : @"/Documents/Baseline",
                                                 @"MNTF_SCREENSHOTS_DIFF" : @"$(PROJECT_DIR)/build/outputs/tests_artifacts/Diff",
                                                 @"MNTF_SCREENSHOTS_DIFF_REAL" : @"/Documents/Screenshots/Diff",
                                                 @"MNTF_SCREENSHOTS_REAL" : @"/Documents/Screenshots"
                                                 }
                                         };
    XCTAssert([dictionary isEqualToDictionary:expectedDictionary], @"Dictionary doesn't match expectation");
}

- (void)testEnvironmentVariableExpansion {
    NSString *schemePath = @"/Users/test/XcodeProject/XcodeProject.xcodeproj/xcshareddata/xcschemes/XcodeProjectTests.xcscheme";

    XCTAssertEqualObjects([BPUtils expandEnvironmentVariable:@"$(SRCROOT)/Resources" withSchemePath:schemePath], @"/Users/test/XcodeProject/Resources");
    XCTAssertEqualObjects([BPUtils expandEnvironmentVariable:@"$(SOURCE_ROOT)/Resources" withSchemePath:schemePath], @"/Users/test/XcodeProject/Resources");
    XCTAssertEqualObjects([BPUtils expandEnvironmentVariable:@"$(PROJECT_DIR)/Resources" withSchemePath:schemePath], @"/Users/test/XcodeProject/Resources");
    XCTAssertEqualObjects([BPUtils expandEnvironmentVariable:@"$(PROJECT_FILE_PATH)" withSchemePath:schemePath], @"/Users/test/XcodeProject/XcodeProject.xcodeproj");
}

@end
