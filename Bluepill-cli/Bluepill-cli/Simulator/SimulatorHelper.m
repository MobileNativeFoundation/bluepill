//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "SimulatorHelper.h"
#import "XCTestConfiguration.h"
#import "BPConfiguration.h"
#import "BPUtils.h"
#import "BPXCTestFile.h"

@implementation SimulatorHelper

+ (NSDictionary *)appLaunchEnvironmentWith:(NSString *)hostAppPath
                            testbundlePath:(NSString *)testBundlePath
                                    config:(BPConfiguration *)config {
    NSString *testSimulatorFrameworkPath = [[hostAppPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSString *dyldLibraryPath = [NSString stringWithFormat:@"%@:%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", testSimulatorFrameworkPath, config.xcodePath];
    return @{
             @"AppTargetLocation" : hostAppPath,
             @"DYLD_FALLBACK_FRAMEWORK_PATH" : [NSString stringWithFormat:@"%@/Library/Frameworks:%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", config.xcodePath, config.xcodePath],
             @"DYLD_FRAMEWORK_PATH" : dyldLibraryPath,
             @"DYLD_INSERT_LIBRARIES" : [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection", config.xcodePath],
             @"DYLD_LIBRARY_PATH" : dyldLibraryPath,
             @"NSUnbufferedIO" : @YES,
             @"TestBundleLocation" : testBundlePath,
             @"XCInjectBundle" : testBundlePath,
             @"XCInjectBundleInto" : hostAppPath,
             @"MNTF_TINKER_DELAY": @0.01,
             @"XCTestConfigurationFilePath" : [SimulatorHelper testEnvironmentWithConfiguration:config],
             };
}

+ (NSString *)testEnvironmentWithConfiguration:(BPConfiguration *)config {
    XCTestConfiguration *xctConfig = [[XCTestConfiguration alloc] init];

    NSString *appName = [self appNameForPath:config.testBundlePath];
    [xctConfig setProductModuleName:appName];
    [xctConfig setTestBundleURL:[NSURL fileURLWithPath:config.testBundlePath]];

    [xctConfig setReportResultsToIDE:NO];
    if (config.testCasesToSkip) {
        [xctConfig setTestsToSkip:[NSSet setWithArray:config.testCasesToSkip]];
    } else if (config.testCasesToRun) {
        // According to @khu, we can't just pass the right setTestsToRun and have it work, so what we do instead
        // is get the full list of tests from the XCTest bundle, then skip everything we don't want to run.
        NSError *error;
        NSString *basename = [[config.testBundlePath lastPathComponent] stringByDeletingPathExtension];
        NSString *executable = [config.testBundlePath stringByAppendingPathComponent:basename];

        BPXCTestFile *xctTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executable withError:&error];
        if (!xctTestFile) {
            [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"Failed to load testcases from %@", [error localizedDescription]]];
            [BPUtils printInfo:WARNING withString:@"Will Run all TestCases"];
        } else {
            NSMutableSet *allTestCases = [[NSMutableSet alloc] initWithArray:xctTestFile.allTestCases];
            NSSet *testsToRun = [[NSSet alloc] initWithArray:config.testCasesToRun];
            [allTestCases minusSet:testsToRun];
            [xctConfig setTestsToSkip:allTestCases];
        }
    }

    NSString *XCTestConfigurationFilename = [NSString stringWithFormat:@"%@/%@-%@",
                                             NSTemporaryDirectory(),
                                             appName,
                                             [xctConfig.sessionIdentifier UUIDString]];
    assert(XCTestConfigurationFilename != nil);
    NSString *XCTestConfigurationFilePath = [XCTestConfigurationFilename stringByAppendingPathExtension:@"xctestconfiguration"];
    if (![NSKeyedArchiver archiveRootObject:xctConfig toFile:XCTestConfigurationFilePath]) {
        NSAssert(NO, @"Couldn't archive XCTestConfiguration to file at path %@", XCTestConfigurationFilePath);
    }
    return XCTestConfigurationFilePath;
}

+ (NSString *)bundleIdForPath:(NSString *)path {
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];

    NSString *bundleId = [dic objectForKey:(NSString *)kCFBundleIdentifierKey];
    return bundleId;
}

+ (NSString *)executablePathforPath:(NSString *)path {
    NSDictionary *appDic = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
    NSString *appExecutable = [appDic objectForKey:(NSString *)kCFBundleExecutableKey];
    return [path stringByAppendingPathComponent:appExecutable];
}

+ (NSString *)appNameForPath:(NSString *)path {
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];

    NSString *bundleId = [dic objectForKey:(NSString *)kCFBundleNameKey];
    return bundleId;
}

@end
