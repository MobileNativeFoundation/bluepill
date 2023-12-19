//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPUtils.h"
#import "BPVersion.h"
#import "BPConstants.h"
#import "BPXCTestFile.h"
#import "BPConfiguration.h"
#import "SimDevice.h"
#import "SimDeviceType.h"
#import "BPExecutionContext.h"
#import "BPSimulator.h"
#import <BPTestInspector/BPTestInspectorConstants.h>

@implementation BPUtils

#define ANSI_COLOR_RED     "\x1b[31m"
#define ANSI_COLOR_GREEN   "\x1b[32m"
#define ANSI_COLOR_YELLOW  "\x1b[33m"
#define ANSI_COLOR_BLUE    "\x1b[34m"
#define ANSI_COLOR_RESET   "\x1b[0m"

typedef struct Message {
    char *text;
    const char *color;
} Message;

Message Messages[] = {
    {" PASSED ", ANSI_COLOR_GREEN },
    {" FAILED ", ANSI_COLOR_RED   },
    {" TIMEOUT", ANSI_COLOR_YELLOW},
    {"  INFO  ", ANSI_COLOR_BLUE  },
    {"  ERROR ", ANSI_COLOR_RED   },
    {" WARNING", ANSI_COLOR_YELLOW},
    {" CRASH  ", ANSI_COLOR_RED   },
    {" DEBUG  ", ANSI_COLOR_YELLOW},
};

static int bp_testing = -1;

#ifdef DEBUG
static BOOL printDebugInfo = YES;
#else
static BOOL printDebugInfo = NO;
#endif

static BOOL quiet = NO;

+ (void)enableDebugOutput:(BOOL)enable {
    printDebugInfo = enable;
    if (quiet && printDebugInfo == YES) quiet = NO;
    NSLog(@"Debug Enabled == %hhd", printDebugInfo);
}

+ (void)quietMode:(BOOL)enable {
    quiet = enable;
}

+ (BOOL)isBuildScript {
    char* buildScript = getenv("BPBuildScript");
    if (buildScript && !strncmp(buildScript, "YES", 3)) {
        return YES;
    }
    return NO;
}

+ (void)printInfo:(BPKind)kind withString:(NSString *)fmt, ... {
    if (kind == DEBUGINFO && !printDebugInfo) {
        return;
    }
    if (quiet && kind != ERROR) return;
    FILE *out = kind == ERROR ? stderr : stdout;
    va_list args;
    va_start(args, fmt);
    NSString *txt = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [self printTo:out kind:kind withString:txt];
}

+ (void)printTo:(FILE*)fd kind:(BPKind)kind withString:(NSString *)txt {
    Message message = Messages[kind];
    NSString *simNum = @"(BLUEPILL) ";
    char *s;
    if (bp_testing < 0) {
        bp_testing = (getenv("_BP_TEST_SUITE") != 0);
    }
    if ((s = getenv("_BP_NUM"))) {
        simNum = [NSString stringWithFormat:@"(BP-%s) ", s];
    }

    // Get timestamp
    char ts[1<<6];
    time_t now;
    struct tm *tms;
    time(&now);
    tms = localtime(&now);
    strftime(ts, 1<<6, "%Y%m%d.%H%M%S", tms);

    const char * __nullable msg = [txt UTF8String];
    char *nl = "\n";
    if (msg && strlen(msg) > 1 && msg[strlen(msg)-1] == '\n') {
        // don't add a new line if it already ends in new line
        nl = "";
    }

    if (isatty(1) && !bp_testing) {
        fprintf(fd, "{%d} %s %s[%s]%s %s%s%s",
                getpid(), ts, message.color, message.text, ANSI_COLOR_RESET, [simNum UTF8String], [txt UTF8String], nl);
    } else {
        fprintf(fd, "{%d} %s [%s] %s%s%s", getpid(), ts, message.text, [simNum UTF8String], [txt UTF8String], nl);
    }
    fflush(fd);
}

+ (NSString *)findExecutablePath:(NSString *)execName {
    NSString *argv0 = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
    NSString *execPath = [[argv0 stringByDeletingLastPathComponent] stringByAppendingPathComponent:execName];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:execPath]) {
        return nil;
    }
    return execPath;
}

+ (NSString *)findBPTestInspectorDYLIB {
    [BPUtils printInfo:INFO withString:@"LTHROCKM DEBUG - looking for dylib"];
    NSString *argv0 = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
    NSString *path = [[argv0 stringByDeletingLastPathComponent] stringByAppendingPathComponent:BPTestInspectorConstants.dylibName];
    if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
        [BPUtils printInfo:INFO withString:@"LTHROCKM DEBUG - fount at path: %@", path];
        return path;
    }
    // The executable may also be in derived data, accessible from the app's current working directory.
    NSString *buildProductsDir = [NSFileManager.defaultManager.currentDirectoryPath stringByDeletingLastPathComponent];
    NSString *iPhoneSimDir = [buildProductsDir stringByAppendingPathComponent:@"Debug-iphonesimulator"];
    path = [iPhoneSimDir stringByAppendingPathComponent:BPTestInspectorConstants.dylibName];
    if ([[NSFileManager defaultManager] isReadableFileAtPath:path]) {
        [BPUtils printInfo:INFO withString:@"LTHROCKM DEBUG - fount at path: %@", path];
        return path;
    }
    [BPUtils printInfo:INFO withString:@"LTHROCKM DEBUG - did not find :("];
    return nil;
}

+ (NSString *)mkdtemp:(NSString *)template withError:(NSError **)errPtr {
    char *dir = strdup([[template stringByAppendingString:@"_XXXXXX"] UTF8String]);
    if (mkdtemp(dir) == NULL) {
        BP_SET_ERROR(errPtr, @"%s", strerror(errno));
        free(dir);
        return nil;
    }
    NSString *ret = [NSString stringWithUTF8String:dir];
    free(dir);
    return ret;
}

+ (NSString *)mkstemp:(NSString *)template withError:(NSError **)errPtr {
    char *file = strdup([[template stringByAppendingString:@".XXXXXX"] UTF8String]);
    int fd = mkstemp(file);
    if (fd < 0) {
        BP_SET_ERROR(errPtr, @"%s", strerror(errno));
        free(file);
        return nil;
    }
    close(fd);
    NSString *ret = [NSString stringWithUTF8String:file];
    free(file);
    return ret;
}

// Expands the exclude or skipped tests, for example into all test methods if test class is mentioned
+ (BPConfiguration *)normalizeConfiguration:(BPConfiguration *)config
                              withTestFiles:(NSArray *)xctTestFiles {

    config = [config mutableCopy];
    NSMutableSet *testsToRun = [NSMutableSet new];
    NSMutableSet *testsToSkip = [NSMutableSet new];
    for (BPXCTestFile *xctFile in xctTestFiles) {
        if (config.testCasesToRun) {
            [testsToRun unionSet:[NSSet setWithArray:[BPUtils expandTests:config.testCasesToRun withTestFile:xctFile]]];
        }
        if (config.testCasesToSkip || xctFile.skipTestIdentifiers) {
            NSMutableArray *allToSkip = [NSMutableArray new];
            [allToSkip addObjectsFromArray:config.testCasesToSkip];
            [allToSkip addObjectsFromArray:xctFile.skipTestIdentifiers];
            [testsToSkip unionSet:[NSSet setWithArray:[BPUtils expandTests:allToSkip withTestFile:xctFile]]];
        }
    }

    if (testsToRun.allObjects.count > 0) {
        config.testCasesToRun = testsToRun.allObjects;
    }
    config.testCasesToSkip = testsToSkip.allObjects;
    return config;
}

+ (BOOL)isStdOut:(NSString *)fileName {
    return [fileName isEqualToString:@"stdout"] || [fileName isEqualToString:@"-"];
}

+ (NSString *)runShell:(NSString *)command {
    NSAssert(command, @"Command should not be nil");
    NSPipe *pipe = [[NSPipe alloc] init];
    NSTask *task = [BPUtils buildShellTaskForCommand:command withPipe:pipe];
    NSAssert(task, @"task should not be nil");
    NSFileHandle *fh = pipe.fileHandleForReading;
    NSAssert(fh, @"fh should not be nil");

    [task launch];
    NSData *data = [fh readDataToEndOfFile];
    [task waitUntilExit];
    NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return result;
}

+ (NSTask *)buildShellTaskForCommand:(NSString *)command {
    return [BPUtils buildShellTaskForCommand:command withPipe: nil];
}

+ (NSTask *)buildShellTaskForCommand:(NSString *)command withPipe:(NSPipe *)pipe {
    NSAssert(command, @"Command should not be nil");
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    if (pipe != nil) {
        task.standardError = pipe;
        task.standardOutput = pipe;
    }
    NSAssert(task, @"task should not be nil");
    return task;
}

+ (NSString *)getCommandStringForTask:(NSTask *)task {
    return [NSString stringWithFormat:@"%@ %@", [task launchPath], [[task arguments] componentsJoinedByString:@" "]];
}

+ (BOOL)runWithTimeOut:(NSTimeInterval)timeout until:(BPRunBlock)block {
    if (!block) {
        return NO;
    }
    NSDate *startDate = [NSDate date];
    BOOL result = NO;

    // Check the return value of the block every 0.1 second till timeout.
    while( -[startDate timeIntervalSinceNow] < timeout && !result) {
        result = block();
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
    }
    return result;
}

#pragma mark - Private Helper Methods

/*!
 @brief expand testcases into a list of fully expanded testcases in the form of 'testsuite/testcase'.

 @discussion searches the given .xctest bundle's entire list of actual testcases
 (that are in the form of 'testsuite/testcase') for testcases that belong to testsuites
 that were provided in the configTestCases.

 @param testCases a list of testcases: each item is either a 'testsuite' or a 'testsuite/testcase'.
 @return a @c NSArray of all the expanded 'testsuite/testcase' items that match the given configTestCases.

 */
+ (NSArray *)expandTests:(NSArray *)testCases withTestFile:(BPXCTestFile *)testFile {
    NSMutableArray *expandedTestCases = [NSMutableArray new];

    for (NSString *testCase in testCases) {
        if ([testCase rangeOfString:@"/"].location == NSNotFound) {
            [testFile.allTestCases enumerateObjectsUsingBlock:^(NSString *actualTestCase, NSUInteger idx, BOOL *stop) {
                if ([actualTestCase hasPrefix:[NSString stringWithFormat:@"%@/", testCase]]) {
                    [expandedTestCases addObject:actualTestCase];
                }
            }];
        } else {
            [expandedTestCases addObject:testCase];
        }
    }
    return expandedTestCases;
}

+ (NSString *)getXcodeRuntimeVersion {
    NSString *xcodeVersion = [BPUtils runShell:@"xcodebuild -version"];
    NSArray *versionStrArray = [xcodeVersion componentsSeparatedByString:@"\n"];
    NSString *lineOne = [versionStrArray objectAtIndex:0];
    NSString *lineTwo = [versionStrArray objectAtIndex:1];
    NSRange xcodeRange = [lineOne rangeOfString:@"Xcode"];
    NSString *xcodeVer = [lineOne substringFromIndex:xcodeRange.location + 6]; //Xcode version string
    NSRange versionRange = [lineTwo rangeOfString:@"version"];
    NSString *buildVer = [lineTwo substringFromIndex:versionRange.location+8]; //build version string
    NSString *runTimeVersion = [NSString stringWithFormat:@"%@ (%@)", xcodeVer, buildVer];
    return runTimeVersion;
}

+ (void)saveDebuggingDiagnostics:(NSString *)outputDirectory {
  BOOL isDir = false;
  NSFileManager *fm = [NSFileManager defaultManager];
  if (outputDirectory == nil || !([fm fileExistsAtPath:outputDirectory isDirectory:&isDir] && isDir)) {
    return;
  }
  NSString *cmd = [NSString stringWithFormat:@"xcrun simctl diagnose -l -b --output='%@/diagnostics'", outputDirectory];
  [BPUtils runShell:cmd];
  cmd = [NSString stringWithFormat:@"ps axuw > '%@'/ps-axuw.log", outputDirectory];
  [BPUtils runShell:cmd];
  cmd = [NSString stringWithFormat:@"df -h > '%@'/df-h.log", outputDirectory];
  [BPUtils runShell:cmd];
}

+ (BOOL)isTestSwiftTest:(NSString *)testName {
    return [testName containsString:@"."] || [testName containsString:@"()"];
}

+ (NSString *)removeSwiftArgumentsFromTestName:(NSString *)testName {
    NSRange range = [testName rangeOfString:@"("];
    if (range.location == NSNotFound) {
        return testName;
    }
    return [NSString stringWithFormat:@"%@()", [testName substringToIndex:range.location]];
}

+ (NSString *)formatSwiftTestForReport:(NSString *)testName {
    NSString *formattedName = testName;
    // Remove prefix of `<bundleName>.`
    NSRange range = [testName rangeOfString:@"."];
    if (range.location != NSNotFound) {
        formattedName = [formattedName substringFromIndex:range.location + 1];
    }
    // Add parentheses
    if (![testName hasSuffix:@"()"]) {
        formattedName = [formattedName stringByAppendingString:@"()"];
    }
    return formattedName;
}

+ (NSString *)formatSwiftTestForXCTest:(NSString *)testName withBundleName:(NSString *)bundleName {
    NSString *formattedName = testName;
    // Remove parentheses
    NSRange range = [formattedName rangeOfString:@"()"];
    if (range.location != NSNotFound) {
        formattedName = [formattedName substringToIndex:range.location];
    }
    // Add `<bundleName>.`
    NSString *bundlePrefix = [bundleName stringByAppendingString:@"."];
    if (![formattedName containsString:bundlePrefix]) {
        formattedName = [NSString stringWithFormat:@"%@.%@", bundleName, formattedName];
    }
    return formattedName;
}

+ (char *)version {
    return BP_VERSION;
}

+ (int)setupWeakLinking:(int)argc argv:(char **)argv {
    // This next part is because we're weak-linking the private Xcode frameworks.
    // This is necessary in case you have multiple versions of Xcode so we dynamically
    // look at the path where Xcode is and add the private framework paths to the
    // DYLD_FALLBACK_FRAMEWORK_PATH environment variable.
    // We want to only do this once, so we use the BP_DYLD_RESOLVED environment variable
    // as a sentinel (geddit? sentinel!)

    if (getenv("BP_DYLD_RESOLVED") != NULL) {
        return 0;
    }
    // Find path
    NSString *xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    if (xcodePath == nil) {
        fprintf(stderr, "Failed to run `/usr/bin/xcode-select -print-path`.\n");
        return 1;
    }

    NSMutableArray *fallbackFrameworkPaths = [@[] mutableCopy];
    if (getenv("DYLD_FALLBACK_FRAMEWORK_PATH")) {
        [fallbackFrameworkPaths addObject:@(getenv("DYLD_FALLBACK_FRAMEWORK_PATH"))];
    } else {
        // If unset, this variable takes on an implicit default (see `man dyld`).
        [fallbackFrameworkPaths addObjectsFromArray:@[
                                                      @"/Library/Frameworks",
                                                      @"/Network/Library/Frameworks",
                                                      @"/System/Library/Frameworks",
                                                      ]];
    }

    [fallbackFrameworkPaths addObjectsFromArray:@[
                                                  [xcodePath stringByAppendingPathComponent:@"Library/PrivateFrameworks"],
                                                  [xcodePath stringByAppendingPathComponent:@"Platforms/MacOSX.platform/Developer/Library/Frameworks"],
                                                  [xcodePath stringByAppendingPathComponent:@"Platforms/iPhoneSimulator.platform/Developer/Library/PrivateFrameworks"],
                                                  [xcodePath stringByAppendingPathComponent:@"../OtherFrameworks"],
                                                  [xcodePath stringByAppendingPathComponent:@"../SharedFrameworks"],
                                                  ]];

    NSString *fallbackFrameworkPath = [fallbackFrameworkPaths componentsJoinedByString:@":"];
    setenv("DYLD_FALLBACK_FRAMEWORK_PATH", [fallbackFrameworkPath UTF8String], 1);

    // Rewrite argv with the full path to the executable
    const char *updatedArgv[argc + 1];

    updatedArgv[0] = [[[NSBundle mainBundle] executablePath] fileSystemRepresentation];
    updatedArgv[argc] = 0;

    for (int i = 1; i < argc; i++) {
        updatedArgv[i] = argv[i];
    }

    // Don't do this setup again...
    setenv("BP_DYLD_RESOLVED", "YES", 1);
    execv(updatedArgv[0], (char *const *)updatedArgv);

    // we should never get here
    assert(!"FAIL");
}

+ (NSDictionary *)loadSimpleJsonFile:(NSString *)filePath
                           withError:(NSError **)errPtr {
    NSData *data = [NSData dataWithContentsOfFile:filePath
                                          options:NSDataReadingMappedIfSafe
                                            error:errPtr];
    if (!data) return nil;

    return [NSJSONSerialization JSONObjectWithData:data
                                           options:NSJSONReadingAllowFragments
                                             error:errPtr];
}

+ (NSDictionary<NSString *,NSNumber *> *)getTestEstimatesByFilePathWithConfig:(BPConfiguration *)config
                                                                    testTimes:(NSDictionary<NSString *,NSNumber *> *)testTimes
                                                               andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    NSMutableDictionary<NSString *,NSNumber *> *testEstimatesByFilePath = [[NSMutableDictionary alloc] init];
    NSDictionary<NSString *, NSSet *> *testsToRunByFilePath = [BPUtils getTestsToRunByFilePathWithConfig:config
                                                                                          andXCTestFiles:xcTestFiles];
    for(NSString *filePath in testsToRunByFilePath) {
        NSSet *bundleTestsToRun = [testsToRunByFilePath objectForKey:filePath];
        double __block testBundleExecutionTime = 0.0;
        [bundleTestsToRun enumerateObjectsUsingBlock:^(id _Nonnull test, BOOL * _Nonnull stop) {
            // TODO: Assign a sensible default if the estimate is not given
            if ([testTimes objectForKey:test]) {
                testBundleExecutionTime += [[testTimes objectForKey:test] doubleValue];
            }
        }];
        testEstimatesByFilePath[filePath] = [NSNumber numberWithDouble:testBundleExecutionTime];
    }
    return testEstimatesByFilePath;
}

+ (NSDictionary<NSString *, NSSet *> *)getTestsToRunByFilePathWithConfig:(BPConfiguration *)config
                                                          andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    NSMutableDictionary<NSString *, NSSet *> *testsToRunByFilePath = [[NSMutableDictionary alloc] init];
    for (BPXCTestFile *xctFile in xcTestFiles) {
        NSMutableSet *bundleTestsToRun = [[NSMutableSet alloc] initWithArray:[xctFile allTestCases]];
        if (config.testCasesToRun) {
            [bundleTestsToRun intersectSet:[[NSSet alloc] initWithArray:config.testCasesToRun]];
        }
        if (config.testCasesToSkip && [config.testCasesToSkip count] > 0) {
            [bundleTestsToRun minusSet:[[NSSet alloc] initWithArray:config.testCasesToSkip]];
        }
        [BPUtils printInfo:INFO withString:@"Bundle: %@; All Tests count: %lu; bundleTestsToRun count: %lu", xctFile.testBundlePath, (unsigned long)[xctFile.allTestCases count], (unsigned long)[bundleTestsToRun count]];
        if (bundleTestsToRun.count > 0) {
            testsToRunByFilePath[xctFile.testBundlePath] = bundleTestsToRun;
        }
    }
    return testsToRunByFilePath;
}

+ (double)timeoutForAllTestsWithConfiguration:(BPConfiguration *)config {
    // Add 1 second per test
    double buffer = 1.0;
    NSInteger testCount = (config.testCasesToRun.count == 0 ? config.allTestCases.count : config.testCasesToRun.count) - config.testCasesToSkip.count;
    return testCount * (config.testCaseTimeout.doubleValue + buffer);
}

+ (double)getTotalTimeWithConfig:(BPConfiguration *)config
                       testTimes:(NSDictionary<NSString *,NSNumber *> *)testTimes
                  andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    double totalTime = 0.0;
    NSDictionary<NSString *, NSSet *> *testsToRunByFilePath = [BPUtils getTestsToRunByFilePathWithConfig:config
                                                                                          andXCTestFiles:xcTestFiles];
    for(NSString *filePath in testsToRunByFilePath) {
        NSSet *bundleTestsToRun = [testsToRunByFilePath objectForKey:filePath];
        double __block testBundleExecutionTime = 0.0;
        [bundleTestsToRun enumerateObjectsUsingBlock:^(id _Nonnull test, BOOL * _Nonnull stop) {
            // TODO: Assign a sensible default if the estimate is not given
            if ([testTimes objectForKey:test]) {
                testBundleExecutionTime += [[testTimes objectForKey:test] doubleValue];
            }
        }];
        totalTime += testBundleExecutionTime;
    }
    return totalTime;
}

#pragma mark - Errors

+ (NSError *)errorWithSignalCode:(NSInteger)signalCode {
    NSString *description = [NSString stringWithFormat:@"Process failed signal code: %@", @(signalCode)];
    return [self errorWithCode:signalCode description:description];
}

+ (NSError *)errorWithExitCode:(NSInteger)exitCode {
    NSString *description = [NSString stringWithFormat:@"Process failed exit code: %@", @(exitCode)];
    return [self errorWithCode:exitCode description:description];
}

+ (NSError *)BPError:(const char *)function andLine:(int)line withFormat:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    return [self errorWithCode:-1 description:msg];
}

+ (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
    NSDictionary<NSString *, NSString *> *userInfo = @{
        NSLocalizedDescriptionKey: description
    };
    return [NSError errorWithDomain:BPErrorDomain code:code userInfo:userInfo];
}

#pragma mark - Architecture Helpers

/**
 We can isolate a single architecture out of a universal binary using the `lipo -extract` command. By doing so, we can
 force an executable (such as XCTest) to always run w/ the architecture we expect. This is to avoid some funny business where
 the architecture selected can be unexpected depending on multiple factors, such as Rosetta, xcode version, etc.
 
 @return the path of the new executable if possible + required, nil otherwise. In nil case, original executable should be used instead.
 */
+ (NSString *)lipoExecutableAtPath:(NSString *)path withContext:(BPExecutionContext *)context {
    // If the executable isn't a universal binary, there's nothing we can do. If we don't
    // support the test bundle type, we'll let it fail later naturally.
    NSArray<NSString *> *executableArchitectures = [self availableArchitecturesForPath:path];
    BOOL isUniversalExecutable = [executableArchitectures containsObject:self.x86_64] && [executableArchitectures containsObject:self.arm64];
    if (!isUniversalExecutable) {
        [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] !isUniversalExecutable"];
        return nil;
    }
    // Now, get the test bundle's architecture.
    NSString *bundlePath =  context.config.testBundlePath;
    NSString *testBundleName = [[bundlePath pathComponents].lastObject componentsSeparatedByString:@"."][0];
    NSString *testBundleBinaryPath = [bundlePath stringByAppendingPathComponent:testBundleName];
    NSArray<NSString *> *testBundleArchitectures = [self availableArchitecturesForPath:testBundleBinaryPath];
    BOOL isUniversalTestBundle = [testBundleArchitectures containsObject:self.x86_64] && [testBundleArchitectures containsObject:self.arm64];

    // If the test bundle is a univeral binary, no need to lipo... xctest (regardless of the arch it's in)
    // should be able to handle it.
    if (isUniversalTestBundle) {
        [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] !isUniversalTestBundle"];
        return nil;
    }

    // If the test bundle's arch isn't supported by the sim, we're in an error state
    NSArray<NSString *> *simArchitectures = [self architecturesSupportedByDevice:context.runner.device];
    if (![simArchitectures containsObject:testBundleArchitectures.firstObject]) {
        [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] ![simArchitectures containsObject:testBundleArchitectures.firstObject]"];
        return nil;
    }
    
    // Now that we've done any error checking, we can handle our real cases,
    // based on what xctest would default to vs. what we need it to do.
    // Note that the universal binary will launch in the same arch as the machine,
    // rather than defaulting to the arch of the parent process.
    //
    //   1) The current arch is x86_64
    //        a) We are in Rosetta       -> xctest will default to arm64
    //        b) We are not in Rosetta   -> xctest will default to x86
    //   2) The current arch is arm64    -> xctest will default to arm64
    //
    // We handle these accordingly:
    //   1a) we lipo if the test bundle is an x86_64 binary
    //   1b) no-op.     ... x86 will get handled automatically, and we have to fail if test bundle is arm64.
    //   1c) no-op.     ... arm64 will get handled automatically, and we have to fail if test bundle is x86.
    BOOL isRosetta = [self.currentArchitecture isEqual:self.x86_64] && isUniversalExecutable;
    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] currentArchitecture = %@", self.currentArchitecture];
    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] isUniversalExecutable = %@", @(isUniversalExecutable)];
    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] testBundleArchitectures = %@", testBundleArchitectures];
    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] isRosetta = %@", @(isRosetta)];
    if (!isRosetta || ![testBundleArchitectures.firstObject isEqual:self.x86_64]) {
        return nil;
    }

    // Now we lipo.
    NSError *error;
    NSString *fileName = [NSString stringWithFormat:@"%@xctest", NSTemporaryDirectory()];
    NSString *thinnedExecutablePath = [BPUtils mkstemp:fileName withError:&error];
    NSString *cmd = [NSString stringWithFormat:@"/usr/bin/lipo %@ -extract %@ -output %@", path, testBundleArchitectures.firstObject, thinnedExecutablePath];
    NSString *__unused output = [BPUtils runShell:cmd];
    return thinnedExecutablePath;
}

/**
 Lipo'ing the universal binary alone to isolate the desired architecture will result in errors.
 Specifically, the newly lipo'ed binary won't be able to find any of the required frameworks
 from within the original binary. So, we need to set up the `DYLD_FRAMEWORK_PATH`
 in the environment to include the paths to these frameworks within the original universal
 executable's binary.
 */
+ (NSString *)correctedDYLDFrameworkPathFromBinary:(NSString *)binaryPath {
    NSString *otoolCommand = [NSString stringWithFormat:@"/usr/bin/otool -l %@", binaryPath];
    NSString *otoolInfo = [BPUtils runShell:otoolCommand];
//    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] otoolInfo = %@", otoolInfo];

    // /usr/bin/otool -l  /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest
    /**
     Example output looks something like this:
     
     ```
     // Lots of stuff we don't care about, followed by a list of `LC_RPATH` entries
     Load command 18
               cmd LC_RPATH
           cmdsize 48
              path @executable_path/path/to/frameworks/ (offset 12)
     // Lots more stuff we don't care about...
     ```
     
     We want to use a regex to extract out each of the `@executable_path/path/to/frameworks/`,
     and then replace `@executable_path` with our original executable's parent directory.
     */
    NSString *pattern = @"(?:^Load command \\d+\n"
    "\\s*cmd LC_RPATH\n"
    "\\s*cmdsize \\d+\n"
    "\\s*path (@executable_path\\/.*) \\(offset \\d+\\))+";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];

    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSString *parentDirectory = [[binaryPath stringByResolvingSymlinksInPath] stringByDeletingLastPathComponent];
    if (regex) {
        NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:otoolInfo
                                                                  options:0
                                                                    range:NSMakeRange(0, otoolInfo.length)];
        for (NSTextCheckingResult *match in matches) {
            // Extract the substring from the input string based on the matched range
            NSString *relativePath = [otoolInfo substringWithRange:[match rangeAtIndex:1]];
            NSString *path = [relativePath stringByReplacingOccurrencesOfString:@"@executable_path" withString:parentDirectory];
            [paths addObject:path];
        }
    } else {
        NSLog(@"Error creating regular expression: %@", error);
    }
    return [paths componentsJoinedByString:@":"];
}

+ (NSArray<NSString *> *)availableArchitecturesForPath:(NSString *)path {
    NSString *cmd = [NSString stringWithFormat:@"/usr/bin/lipo -archs %@", path];
    return [[BPUtils runShell:cmd] componentsSeparatedByString:@" "];
}

+ (NSArray<NSString *> *)architecturesSupportedByDevice:(SimDevice *)device {
    NSArray<NSNumber *> *simSupportedArchitectures = device.deviceType.supportedArchs;
    NSMutableArray<NSString *> *simArchitectures = [NSMutableArray array];
    for (NSNumber *supportedArchitecture in simSupportedArchitectures) {
        [simArchitectures addObject:[self architectureName:supportedArchitecture.intValue]];
    }
    return [simArchitectures copy];
}

+ (NSString *)arm64 {
    return [self architectureName:CPU_TYPE_ARM64];
}

+ (NSString *)x86_64 {
    return [self architectureName:CPU_TYPE_X86_64];
}

+ (NSString *)architectureName:(integer_t)architecture {
    if (architecture == CPU_TYPE_X86_64) {
        return @"x86_64";
    } else if (architecture == CPU_TYPE_ARM64) {
        return @"arm64";
    }
    return nil;
}

+ (NSString *)currentArchitecture {
    #if TARGET_CPU_ARM64
        return [self architectureName:CPU_TYPE_ARM64];
    #elif TARGET_CPU_X86_64
        return [self architectureName:CPU_TYPE_X86_64];
    #else
        return nil;
    #endif
}

@end
