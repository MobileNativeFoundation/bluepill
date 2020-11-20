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

+ (NSError *)BPError:(const char *)function andLine:(int)line withFormat:(NSString *)fmt, ... {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    return [NSError errorWithDomain:BPErrorDomain
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: msg}];
}

+ (NSString *)findExecutablePath:(NSString *)execName {
    NSString *argv0 = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
    NSString *execPath = [[argv0 stringByDeletingLastPathComponent] stringByAppendingPathComponent:execName];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:execPath]) {
        return nil;
    }
    return execPath;
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
  NSString *cmd = [NSString stringWithFormat:@"xcrun simctl diagnose -l -b --output='%@/diagnostics' --data-container", outputDirectory];
  [BPUtils runShell:cmd];
  cmd = [NSString stringWithFormat:@"ps axuw > '%@'/ps-axuw.log", outputDirectory];
  [BPUtils runShell:cmd];
  cmd = [NSString stringWithFormat:@"df -h > '%@'/df-h.log", outputDirectory];
  [BPUtils runShell:cmd];
}

+ (NSString *)trimTrailingParanthesesFromTestName:(NSString *)testName {
    // Recently, the extracted symbols from Swift apps began having parenthesis at the end.
    // Extracting just the name of the test by reading up to the occurrence of the first open brace.
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"[^\(]+"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSArray<NSTextCheckingResult *> *regexMatches = [regex matchesInString:testName options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, [testName length])];
    if (regexMatches.count == 0) {
        return nil;
    }
    return [testName substringWithRange:regexMatches.firstObject.range];
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

@end
