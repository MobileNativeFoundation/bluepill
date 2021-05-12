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
#import "PrivateHeaders/XCTest/XCTestConfiguration.h"
#import "PrivateHeaders/XCTest/XCTTestIdentifierSet.h"


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
        [xctConfig setTestsToSkip:[[XCTTestIdentifierSet alloc] initWithArray:config.testCasesToSkip]];
    }

    if (config.testCasesToRun) {
        // According to @khu, we can't just pass the right setTestsToRun and have it work, so what we do instead
        // is get the full list of tests from the XCTest bundle, then skip everything we don't want to run.

        NSMutableSet *testsToSkip = [[NSMutableSet alloc] initWithArray:config.allTestCases];
        NSSet *testsToRun = [[NSSet alloc] initWithArray:config.testCasesToRun];
        [testsToSkip minusSet:testsToRun];
        if (xctConfig.testsToSkip) {
            [testsToSkip unionSet:[NSSet setWithArray:config.testCasesToSkip]];
        }
        [xctConfig setTestsToSkip:[[XCTTestIdentifierSet alloc] initWithSet:testsToSkip]];
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
