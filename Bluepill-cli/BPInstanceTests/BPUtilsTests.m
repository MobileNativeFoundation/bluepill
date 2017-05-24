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
#import "BPXCTestFile.h"
#import "BPTestHelper.h"
#import "BPConfiguration.h"

@interface BPUtilsTests : XCTestCase
@property (nonatomic, strong) BPXCTestFile *xcTestFile;
@property (nonatomic, strong) BPConfiguration *config;
@end

@implementation BPUtilsTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
    
    NSString *testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    NSString *basename = [[testBundlePath lastPathComponent] stringByDeletingPathExtension];
    NSString *executable = [testBundlePath stringByAppendingPathComponent:basename];
    
    self.xcTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executable
                                                  isUITestFile:NO
                                                     withError:nil];
    
    self.config = [BPConfiguration new];
    self.config.program = BP_MASTER;
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
                                                 @"MNTF_SCREENSHOTS_REAL" : @"/Documents/Screenshots",
                                                 @"TA_SCREENSHOTS_REAL" : @"/Documents/Screenshots"
                                                 }
                                         };
    XCTAssert([dictionary isEqualToDictionary:expectedDictionary], @"Dictionary doesn't match expectation");
}

- (void)testNormalizingConfigurationExcludesAllTestsInExcludedTestSuite {
    self.config.testCasesToSkip = @[@"BPSampleAppTests"];
    
    NSMutableSet *expectedTestCasesToSkip = [NSMutableSet new];
    for (NSString *testCaseToSkip in self.xcTestFile.allTestCases) {
        if ([testCaseToSkip hasPrefix:@"BPSampleAppTests/"]) {
            [expectedTestCasesToSkip addObject:testCaseToSkip];
        }
    }
    BPConfiguration *normalizedConfig = [BPUtils normalizeConfiguration:self.config
                                                          withTestFiles:@[self.xcTestFile]];
    XCTAssertTrue([[NSSet setWithArray:normalizedConfig.testCasesToSkip] isEqualToSet:expectedTestCasesToSkip]);
}

- (void)testNormalizingConfigurationDoesntExcludeTestSuiteWithSimilarPrefix {
    self.config.testCasesToSkip = @[@"BPSampleAppTes"];
    
    NSMutableSet *testCasesNotToSkip = [NSMutableSet new];
    for (NSString *testCase in self.xcTestFile.allTestCases) {
        if ([testCase hasPrefix:@"BPSampleAppTests/"]) {
            [testCasesNotToSkip addObject:testCase];
        }
    }
    BPConfiguration *normalizedConfig = [BPUtils normalizeConfiguration:self.config
                                                          withTestFiles:@[self.xcTestFile]];
    
    XCTAssertFalse([[NSSet setWithArray:normalizedConfig.testCasesToSkip] isEqualToSet:testCasesNotToSkip]);
}

- (void)testNormalizingConfigurationOnlyIncludesTestsInIncludedTestSuite {
    self.config.testCasesToRun = @[@"BPSampleAppTests"];
    
    NSMutableSet *expectedTestCasesToRun = [NSMutableSet new];
    for (NSString *testCaseToRun in self.xcTestFile.allTestCases) {
        if ([testCaseToRun hasPrefix:@"BPSampleAppTests/"]) {
            [expectedTestCasesToRun addObject:testCaseToRun];
        }
    }
    BPConfiguration *normalizedConfig = [BPUtils normalizeConfiguration:self.config
                                                          withTestFiles:@[self.xcTestFile]];
    
    XCTAssertTrue([[NSSet setWithArray:normalizedConfig.testCasesToRun] isEqualToSet:expectedTestCasesToRun]);
}

- (void)testNormalizingConfigurationNoTestsWhenIncludedTestSuiteHasSimilarButNonexistentPrefix {
    self.config.testCasesToRun = @[@"BPSampleAppTes"];
    
    NSMutableSet *testCasesNotToRun = [NSMutableSet new];
    for (NSString *testCase in self.xcTestFile.allTestCases) {
        if ([testCase hasPrefix:@"BPSampleAppTests/"]) {
            [testCasesNotToRun addObject:testCase];
        }
    }
    
    BPConfiguration *normalizedConfig = [BPUtils normalizeConfiguration:self.config
                                                          withTestFiles:@[self.xcTestFile]];
    
    XCTAssertFalse([[NSSet setWithArray:normalizedConfig.testCasesToRun] isEqualToSet:testCasesNotToRun]);
}

@end
