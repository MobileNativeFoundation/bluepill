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
    if ((s = getenv("_BP_SIM_NUM"))) {
        simNum = [NSString stringWithFormat:@"(SIM-%s) ", s];
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
        if (error) {
            *error = BP_ERROR(@"%s", strerror(errno));
        }
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
        if (error) {
            *error = BP_ERROR(@"%s", strerror(errno));
        }
        free(file);
        return nil;
    }
    close(fd);
    NSString *ret = [NSString stringWithUTF8String:file];
    free(file);
    return ret;
}

+ (BOOL)isStdOut:(NSString *)fileName {
    return [fileName isEqualToString:@"stdout"] || [fileName isEqualToString:@"-"];
}

+ (NSDictionary *)buildArgsAndEnvironmentWith:(NSString *)schemePath {
    NSMutableDictionary *argsAndEnv = [NSMutableDictionary new];
    argsAndEnv[@"args"]  = [NSMutableArray new];
    argsAndEnv[@"env"]  = [NSMutableDictionary new];

    NSData *xmlData = [[NSMutableData alloc] initWithContentsOfFile:schemePath];
    NSError *error;
    if (xmlData) {
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:xmlData options:0 error:&error];
        NSArray *argsNodes =
        [document nodesForXPath:[NSString stringWithFormat:@"//%@//CommandLineArgument", @"LaunchAction"] error:&error];
        NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);
        NSArray *envNodes =
        [document nodesForXPath:[NSString stringWithFormat:@"//%@//EnvironmentVariable", @"LaunchAction"] error:&error];
        for (NSXMLElement *node in argsNodes) {
            NSString *argument = [[node attributeForName:@"argument"] stringValue];
            NSArray *argumentsArray = [argument componentsSeparatedByString:@" "];
            for (NSString *arg in argumentsArray) {
                if (![arg isEqualToString:@""]) {
                    [argsAndEnv[@"args"] addObject:arg];
                }
            }
        }

        [argsAndEnv[@"args"] addObjectsFromArray:@[@"-NSTreatUnknownArgumentsAsOpen", @"NO", @"-ApplePersistenceIgnoreState", @"YES"]];

        for (NSXMLElement *node in envNodes) {
            NSString *key = [[node attributeForName:@"key"] stringValue];
            NSString *value = [[node attributeForName:@"value"] stringValue];
            argsAndEnv[@"env"][key] = value;

        }
    }
    NSAssert(error == nil, @"Failed to get nodes: %@", [error localizedFailureReason]);
    return argsAndEnv;
}

+ (NSString *)runShell:(NSString *)command {
    NSAssert(command, @"Command should not be nil");
    NSTask *task = [NSTask new];
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    NSPipe *pipe = [NSPipe new];
    task.standardError = pipe;
    task.standardOutput = pipe;
    NSFileHandle *fh = pipe.fileHandleForReading;
    [task launch];
    [task waitUntilExit];
    NSData *data = [fh readDataToEndOfFile];
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
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

@end
