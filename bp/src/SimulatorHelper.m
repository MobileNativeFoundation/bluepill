//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "SimulatorHelper.h"
#import "BPConfiguration.h"
#import "BPUtils.h"
#import "BPXCTestFile.h"
#import "SimDevice.h"
#import "PrivateHeaders/XCTest/XCTestConfiguration.h"
#import "PrivateHeaders/XCTest/XCTTestIdentifier.h"
#import "PrivateHeaders/XCTest/XCTTestIdentifierSet.h"
#import <BPTestInspector/BPTestCaseInfo.h>


@implementation SimulatorHelper

+ (BOOL)loadFrameworksWithXcodePath:(NSString *)xcodePath {
    // Check the availablity of frameworks

    NSString *sharedFrameworksPath = [xcodePath stringByDeletingLastPathComponent];
    NSArray *ar = @[
                    [NSString stringWithFormat:@"%@/DVTFoundation.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTAnalyticsClient.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTAnalytics.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTPortal.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTSourceControl.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/SourceKit.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTSourceControl.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTAnalytics.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/IDEFoundation.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/DVTFoundation.framework", sharedFrameworksPath],
                    [NSString stringWithFormat:@"%@/SimulatorKit.framework", sharedFrameworksPath]
                    ];
    for (NSString *address in ar) {
        NSBundle *bl = [NSBundle bundleWithPath:address];
        NSError *error;
        [bl loadAndReturnError:&error];
        if (error) {
            NSLog(@"Failed to load framework %@, with error %@",address, error);
            return NO;
        }
    }
    NSArray *requiredClasses = @[@"SimDevice",
                                 @"SimDeviceFramebufferService",
                                 @"DTXConnection",
                                 @"DTXRemoteInvocationReceipt",
                                 @"DVTDevice",
                                 @"IDEFoundationTestInitializer",
                                 @"XCTestConfiguration"];
    for (NSString *rc in requiredClasses) {
        if (NSClassFromString(rc)) {
            [BPUtils printInfo:DEBUGINFO withString:@"%@ is loaded..", rc];
        } else {
            return NO;
        }
    }
    return YES;
}

+ (NSDictionary *)logicTestEnvironmentWithConfig:(BPConfiguration *)config
                              stdoutRelativePath:(NSString *)path {
    NSMutableDictionary<NSString *, id> *environment = [@{
        kOptionsStdoutKey: path,
        kOptionsStderrKey: path,
    } mutableCopy];
    if (config.dyldFrameworkPath) {
        environment[@"DYLD_FRAMEWORK_PATH"] = config.dyldFrameworkPath;
        // DYLD_LIBRARY_PATH is required specifically for swift tests, which require libXCTestSwiftSupport,
        // which must be findable in the library path.
        environment[@"DYLD_LIBRARY_PATH"] = config.dyldFrameworkPath;
    }
    [environment addEntriesFromDictionary:config.environmentVariables];
    return [environment copy];
}

+ (NSDictionary *)appLaunchEnvironmentWithBundleID:(NSString *)hostBundleID
                                            device:(SimDevice *)device
                                            config:(BPConfiguration *)config {
    NSString *hostAppExecPath = [SimulatorHelper executablePathforPath:config.appBundlePath];
    NSString *hostAppPath = [hostAppExecPath stringByDeletingLastPathComponent];
    NSString *testSimulatorFrameworkPath = [hostAppPath stringByDeletingLastPathComponent];
    NSString *libXCTestBundleInjectPath = [[hostAppPath stringByAppendingPathComponent:@"Frameworks"] stringByAppendingPathComponent:@"libXCTestBundleInject.dylib"];
    NSString *libXCTestBundleInjectValue = libXCTestBundleInjectPath;
    if (![NSFileManager.defaultManager fileExistsAtPath:libXCTestBundleInjectPath]) {
        [BPUtils printInfo:DEBUGINFO withString:@"Not injecting libXCTestBundleInject dylib because it was not found in the app host bundle at path: %@", libXCTestBundleInjectValue];
        libXCTestBundleInjectValue = @"";
    }
    NSMutableDictionary<NSString *, NSString *> *environment = [[NSMutableDictionary alloc] init];
    environment[@"DYLD_FALLBACK_FRAMEWORK_PATH"] = [NSString stringWithFormat:@"%@/Library/Frameworks:%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", config.xcodePath, config.xcodePath];
    environment[@"DYLD_FALLBACK_LIBRARY_PATH"] = [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/usr/lib", config.xcodePath];
    environment[@"DYLD_INSERT_LIBRARIES"] = libXCTestBundleInjectValue;
    environment[@"DYLD_LIBRARY_PATH"] = [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", config.xcodePath];
    environment[@"DYLD_ROOT_PATH"] = [NSString stringWithFormat:@"%@/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot", config.xcodePath];
    environment[@"NSUnbufferedIO"] = @"1";
    environment[@"OS_ACTIVITY_DT_MODE"] = @"1";
    environment[@"XCODE_DBG_XPC_EXCLUSIONS"] = @"com.apple.dt.xctestSymbolicator";
    environment[@"XPC_FLAGS"] = @"0x0";
    environment[@"XCTestConfigurationFilePath"] = [SimulatorHelper testEnvironmentWithConfiguration:config];
    environment[@"__XCODE_BUILT_PRODUCTS_DIR_PATHS"] = testSimulatorFrameworkPath;
    environment[@"__XPC_DYLD_FRAMEWORK_PATH"] = testSimulatorFrameworkPath;
    environment[@"__XPC_DYLD_LIBRARY_PATH"] = testSimulatorFrameworkPath;

    if (config.outputDirectory) {
        NSString *coveragePath = [config.outputDirectory stringByAppendingPathComponent:@"%p.profraw"];

        environment[@"LLVM_PROFILE_FILE"] = coveragePath;
        environment[@"__XPC_LLVM_PROFILE_FILE"] = coveragePath;
    }

    return environment;
}

+ (NSString *)testEnvironmentWithConfiguration:(BPConfiguration *)config {
    XCTestConfiguration *xctConfig = [[XCTestConfiguration alloc] init];

    NSString *testBundlePath = config.testBundlePath;
    NSString *appName = [self appNameForPath:testBundlePath];
    NSString *testHostPath;
    xctConfig.productModuleName = appName;
    xctConfig.testBundleURL = [NSURL fileURLWithPath:testBundlePath];
    xctConfig.sessionIdentifier = config.sessionIdentifier;
    xctConfig.treatMissingBaselinesAsFailures = NO;
    xctConfig.targetApplicationPath = config.appBundlePath;
    xctConfig.reportResultsToIDE = YES;
    xctConfig.automationFrameworkPath = [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks/XCTAutomationSupport.framework", config.xcodePath];
    testHostPath = config.appBundlePath;

    NSString *bundleID = [self bundleIdForPath:config.appBundlePath];
    xctConfig.testApplicationDependencies = config.dependencies.count > 0 ? config.dependencies : @{bundleID: config.appBundlePath};

    if (config.testRunnerAppPath) {
        xctConfig.targetApplicationBundleID = bundleID;
        xctConfig.initializeForUITesting = YES;
        xctConfig.disablePerformanceMetrics = NO;
        xctConfig.reportActivities = YES;
        xctConfig.testsMustRunOnMainThread = YES;
        testHostPath = config.testRunnerAppPath;
    }

    if (config.testCasesToSkip) {
        NSMutableArray <XCTTestIdentifier*> *xctTests = [[NSMutableArray alloc] init];
        for (NSString *test in config.testCasesToSkip) {
            [xctTests addObject:[[XCTTestIdentifier alloc] initWithStringRepresentation:test]];
        }
        [xctConfig setTestsToSkip:[[XCTTestIdentifierSet alloc] initWithArray:xctTests]];
    }

    if (config.testCasesToRun) {
        NSMutableArray <XCTTestIdentifier *> *xctTests = [[NSMutableArray alloc] init];
        for (NSString *test in config.testCasesToRun) {
            [xctTests addObject:[[XCTTestIdentifier alloc] initWithStringRepresentation:test]];
        }
        [xctConfig setTestsToRun:[[XCTTestIdentifierSet alloc] initWithSet:xctTests]];
    }

    NSString *XCTestConfigurationFilename = [NSString stringWithFormat:@"%@/%@-%@",
                                             NSTemporaryDirectory(),
                                             appName,
                                             [xctConfig.sessionIdentifier UUIDString]];
    assert(XCTestConfigurationFilename != nil);
    NSString *XCTestConfigurationFilePath = [XCTestConfigurationFilename stringByAppendingPathExtension:@"xctestconfiguration"];
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:xctConfig requiringSecureCoding:TRUE error:nil];
    [data writeToFile:XCTestConfigurationFilePath atomically:TRUE];
    return XCTestConfigurationFilePath;
}

+ (NSString *)bundleIdForPath:(NSString *)path {
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];

    NSString *platform = [dic objectForKey:@"DTPlatformName"];
    if (platform && ![platform isEqualToString:@"iphonesimulator"]) {
        [BPUtils printInfo:ERROR withString:@"Wrong platform in %@. Expected 'iphonesimulator', found '%@'", path, platform];
        return nil;
    }

    NSString *bundleId = [dic objectForKey:(NSString *)kCFBundleIdentifierKey];
    if (!bundleId) {
        [BPUtils printInfo:ERROR withString:@"Could not extract bundleID: %@", dic];
    }
    return bundleId;
}

+ (NSArray<NSString *> *)testsToRunWithConfig:(BPConfiguration *)config {
    // First, standardize all swift test names:
    NSMutableArray<NSString *> *allTests = [self formatTestNamesForXCTest:config.allTestCases withConfig:config];
    NSMutableArray<NSString *> *testsToRun = [self formatTestNamesForXCTest:config.testCasesToRun withConfig:config];
    NSArray<NSString *> *testsToSkip = [self formatTestNamesForXCTest:config.testCasesToSkip withConfig:config];

    // If there's no tests to skip, we can return these back otherwise unaltered.
    // Otherwise, we'll need to remove any tests from `testsToRun` that are in our skip list.
    if (testsToSkip.count == 0) {
        return [(testsToRun ?: allTests) copy];
    }
    
    // If testCasesToRun was empty/nil, we default to all tests
    if (testsToRun.count == 0) {
        testsToRun = allTests;
    }
    [testsToRun filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *testName, NSDictionary<NSString *,id> * _Nullable bindings) {
        return ![testsToSkip containsObject:testName];
    }]];
    return [testsToRun copy];
}

+ (nullable NSMutableArray<NSString *> *)formatTestNamesForXCTest:(nullable NSArray<NSString *> *)tests
                                                       withConfig:(BPConfiguration *)config {
    if (!tests) {
        return nil;
    }
    [BPUtils printInfo:DEBUGINFO withString:@"Formatting test names. config.allTests: %@", config.allTests];
    NSMutableArray<NSString *> *formattedTests = [NSMutableArray array];
    for (NSString *testName in tests) {
        BPTestCaseInfo *info = config.allTests[testName];
        if (info) {
            [formattedTests addObject:info.standardizedFullName];
        } else {
            [BPUtils printInfo:DEBUGINFO withString:@"Omitting false positive test method from test list: %@", testName];
        }
    }
    return formattedTests;
}

// Intercept stdout, stderr and post as simulator-output events
+ (NSString *)makeStdoutFileOnDevice:(SimDevice *)device {
    NSString *stdout_stderr = [NSString stringWithFormat:@"%@/tmp/stdout_stderr_%@", device.dataPath, [[device UDID] UUIDString]];
    return [self createFileWithPathTemplate:stdout_stderr];
}

+ (NSString *)makeTestWrapperOutputFileOnDevice:(SimDevice *)device {
    NSString *stdout_stderr = [NSString stringWithFormat:@"%@/tmp/BPTestInspector_testInfo_%@", device.dataPath, [[device UDID] UUIDString]];
    return [self createFileWithPathTemplate:stdout_stderr];
}

+ (NSString *)createFileWithPathTemplate:(NSString *)pathTemplate {
    NSString *fullPath = [BPUtils mkstemp:pathTemplate withError:nil];
    assert(fullPath != nil);

    [[NSFileManager defaultManager] removeItemAtPath:fullPath error:nil];

    // Create empty file so we can tail it and the app can write to it
    [[NSFileManager defaultManager] createFileAtPath:fullPath
                                            contents:nil
                                          attributes:nil];
    return fullPath;
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
