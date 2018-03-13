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

+ (NSDictionary *)appLaunchEnvironmentWithBundleID:(NSString *)hostBundleID
                                            device:(SimDevice *)device
                                            config:(BPConfiguration *)config {
    NSString *hostAppExecPath = [SimulatorHelper executablePathforPath:config.appBundlePath];
    NSString *testSimulatorFrameworkPath = [[hostAppExecPath stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    NSString *dyldLibraryPath = [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", config.xcodePath];
    NSMutableDictionary<NSString *, NSString *> *environment = [@{
//                                                                  @"DYLD_PRINT_ENV": @YES,
//                                                                  @"DYLD_PRINT_LIBRARIES": @YES,
                                                                  @"DYLD_FALLBACK_FRAMEWORK_PATH" : [NSString stringWithFormat:@"%@/Library/Frameworks:%@/Platforms/iPhoneSimulator.platform/Developer/Library/Frameworks", config.xcodePath, config.xcodePath],
                                                                  @"DYLD_FRAMEWORK_PATH" : dyldLibraryPath,
                                                                  @"DYLD_INSERT_LIBRARIES" : [NSString stringWithFormat:@"%@/Platforms/iPhoneOS.platform/Developer/Library/CoreSimulator/Profiles/Runtimes/iOS.simruntime/Contents/Resources/RuntimeRoot/Developer/usr/lib/libXCTTargetBootstrapInject.dylib", config.xcodePath],
                                                                  @"DYLD_LIBRARY_PATH" : dyldLibraryPath,
                                                                  @"NSUnbufferedIO" : @YES,
                                                                  @"OS_ACTIVITY_DT_MODE" : @YES,
                                                                  @"MNTF_TINKER_DELAY": @0.01,
                                                                  @"XCODE_DBG_XPC_EXCLUSIONS" : @"com.apple.dt.xctestSymbolicator",
                                                                  @"XCTestConfigurationFilePath" : [SimulatorHelper testEnvironmentWithConfiguration:config],
                                                                  @"__XCODE_BUILT_PRODUCTS_DIR_PATHS" : testSimulatorFrameworkPath,
                                                                  @"__XPC_DYLD_FRAMEWORK_PATH" : testSimulatorFrameworkPath,
                                                                  @"__XPC_DYLD_LIBRARY_PATH" : testSimulatorFrameworkPath,
                                                                  } mutableCopy];

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

    if (config.testRunnerAppPath) {
        xctConfig.targetApplicationBundleID = [self bundleIdForPath:config.appBundlePath];
        xctConfig.initializeForUITesting = YES;
        xctConfig.disablePerformanceMetrics = NO;
        xctConfig.reportActivities = YES;
        xctConfig.testsMustRunOnMainThread = YES;
        xctConfig.pathToXcodeReportingSocket = nil;
        testHostPath = config.testRunnerAppPath;
    }

    if (config.testCasesToSkip) {
        [xctConfig setTestsToSkip:[NSSet setWithArray:config.testCasesToSkip]];
    }

    if (config.testCasesToRun) {
        // According to @khu, we can't just pass the right setTestsToRun and have it work, so what we do instead
        // is get the full list of tests from the XCTest bundle, then skip everything we don't want to run.

        NSMutableSet *testsToSkip = [[NSMutableSet alloc] initWithArray:config.allTestCases];
        NSSet *testsToRun = [[NSSet alloc] initWithArray:config.testCasesToRun];
        [testsToSkip minusSet:testsToRun];
        if (xctConfig.testsToSkip) {
            [testsToSkip unionSet:xctConfig.testsToSkip];
        }
        [xctConfig setTestsToSkip:testsToSkip];
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
    NSLog(@"hello XCTestConfigurationFilePath: %@", XCTestConfigurationFilePath);
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
