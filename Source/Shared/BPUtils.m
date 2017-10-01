//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPUtils.h"
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
    NSLog(@"Enable == %hhd", enable);
    printDebugInfo = enable;
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
    NSString *simNum = @"";
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

    if (isatty(1) && !bp_testing) {
        fprintf(fd, "{%d} %s %s[%s]%s %s%s\n",
                getpid(), ts, message.color, message.text, ANSI_COLOR_RESET, [simNum UTF8String], [txt UTF8String]);
    } else {

        fprintf(fd, "{%d} %s [%s] %s%s\n", getpid(), ts, message.text, [simNum UTF8String], [txt UTF8String]);
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


+ (NSString *)mkdtemp:(NSString *)template withError:(NSError **)error {
    char *dir = strdup([[template stringByAppendingString:@"_XXXXXX"] UTF8String]);
    if (mkdtemp(dir) == NULL) {
        BP_SET_ERROR(error, @"%s", strerror(errno));
        free(dir);
        return nil;
    }
    NSString *ret = [NSString stringWithUTF8String:dir];
    free(dir);
    return ret;
}

+ (NSString *)mkstemp:(NSString *)template withError:(NSError **)error {
    char *file = strdup([[template stringByAppendingString:@".XXXXXX"] UTF8String]);
    int fd = mkstemp(file);
    if (fd < 0) {
        BP_SET_ERROR(error, @"%s", strerror(errno));
        free(file);
        return nil;
    }
    close(fd);
    NSString *ret = [NSString stringWithUTF8String:file];
    free(file);
    return ret;
}


+ (BPConfiguration *)normalizeConfiguration:(BPConfiguration *)config
                              withTestFiles:(NSArray *)xctTestFiles {
    
    config = [config mutableCopy];
    NSMutableSet *testsToRun = [NSMutableSet new];
    NSMutableSet *testsToSkip = [NSMutableSet new];
    for (BPXCTestFile *xctFile in xctTestFiles) {
        if (config.testCasesToRun) {
            [testsToRun unionSet:[NSSet setWithArray:[BPUtils expandTests:config.testCasesToRun withTestFile:xctFile]]];
        }
        if (config.testCasesToSkip) {
            [testsToSkip unionSet:[NSSet setWithArray:[BPUtils expandTests:config.testCasesToSkip withTestFile:xctFile]]];
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
    NSTask *task = [[NSTask alloc] init];
    NSData *data;
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    NSPipe *pipe = [[NSPipe alloc] init];
    task.standardError = pipe;
    task.standardOutput = pipe;
    NSFileHandle *fh = pipe.fileHandleForReading;
    if (task) {
        [task launch];
    } else {
        NSAssert(task, @"task should not be nil");
    }
    if (fh) {
        data = [fh readDataToEndOfFile];
    } else {
        NSAssert(task, @"fh should not be nil");
    }
    [task waitUntilExit];
    NSString *result = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return result;
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

@end
