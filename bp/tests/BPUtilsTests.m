//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPExitStatus.h"
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

    self.xcTestFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:testBundlePath
                                                andHostAppBundle:[BPTestHelper sampleAppBalancingTestsBundlePath]
                                                       withError:nil];
    
    self.config = [BPConfiguration new];
    self.config.program = BP_MASTER;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
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

- (void) testTrailingParanthesesInTestNames {
    NSMutableSet *testCasesWithParantheses = [NSMutableSet new];
    for (NSString *testCase in self.xcTestFile.allTestCases) {
        if ([testCase containsString:@"("] || [testCase containsString:@")"]) {
            [testCasesWithParantheses addObject:testCase];
        }
    }
    XCTAssert([testCasesWithParantheses count] == 0);
}

- (void) testExitStatus {
    BPExitStatus exitCode;

    exitCode = 0;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusAllTestsPassed"]);
    exitCode = 1;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusTestsFailed"]);
    exitCode = 2;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusSimulatorCreationFailed"]);
    exitCode = 4;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusInstallAppFailed"]);
    exitCode = 8;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusInterrupted"]);
    exitCode = 16;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusSimulatorCrashed"]);
    exitCode = 32;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusLaunchAppFailed"]);
    exitCode = 64;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusTestTimeout"]);
    exitCode = 128;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusAppCrashed"]);
    exitCode = 256;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusSimulatorDeleted"]);
    exitCode = 512;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusUninstallAppFailed"]);
    exitCode = 1024;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusSimulatorReuseFailed"]);
    exitCode = 3;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusTestsFailed BPExitStatusSimulatorCreationFailed"]);
    exitCode = 192;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusTestTimeout BPExitStatusAppCrashed"]);
    exitCode = 2048;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"UNKNOWN_BPEXITSTATUS - 2048"]);
    exitCode = 2050;
    XCTAssert([[BPExitStatusHelper stringFromExitStatus: exitCode] isEqualToString:@"BPExitStatusSimulatorCreationFailed UNKNOWN_BPEXITSTATUS - 2048"]);
}

- (void) testBuildShellTaskForCommand_withoutPipe {
    NSString *command = @"ls -al";
    NSTask *task = [BPUtils buildShellTaskForCommand:command];
    XCTAssertEqual(task.launchPath, @"/bin/sh");
    XCTAssertEqual(task.arguments.count, 2);
    XCTAssertEqual(task.arguments[0], @"-c");
    XCTAssertEqual(task.arguments[1], command);
    XCTAssertFalse(task.isRunning);
}

- (void) testBuildShellTaskForCommand_withPipe {
    NSString *command = @"ls -al";
    NSPipe *pipe = [[NSPipe alloc] init];
    NSTask *task = [BPUtils buildShellTaskForCommand:command withPipe: pipe];
    XCTAssertEqual(task.standardError, pipe);
    XCTAssertEqual(task.standardOutput, pipe);
    XCTAssertEqual(task.launchPath, @"/bin/sh");
    XCTAssertEqual(task.arguments.count, 2);
    XCTAssertEqual(task.arguments[0], @"-c");
    XCTAssertEqual(task.arguments[1], command);
    XCTAssertFalse(task.isRunning);
}

@end
