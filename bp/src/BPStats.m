//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPStats.h"
#import "BPWriter.h"
#import "BPUtils.h"

@interface BPStat : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, strong) NSString *result;
@end

@interface BPCounter : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *timeStamp;
@property (nonatomic, strong) NSDictionary <NSString *, NSNumber *> *counters;
@end

@interface BPStats()

@property (nonatomic, strong) NSMutableDictionary<NSString *,BPStat *> *stats;
@property (nonatomic, strong) NSMutableArray <BPCounter *> *counters;
@property (nonatomic, strong) BPStat *applicationTime;

@property (nonatomic, assign) NSInteger testsTotal;
@property (nonatomic, assign) NSInteger testFailures;
@property (nonatomic, assign) NSInteger testErrors;
@property (nonatomic, assign) NSInteger simCrashes;
@property (nonatomic, assign) NSInteger appCrashes;
@property (nonatomic, assign) NSInteger retries;
@property (nonatomic, assign) NSInteger runtimeTimeout;
@property (nonatomic, assign) NSInteger outputTimeout;
@property (nonatomic, assign) NSInteger simulatorCreateFailures;
@property (nonatomic, assign) NSInteger simulatorDeleteFailures;
@property (nonatomic, assign) NSInteger simulatorInstallFailures;
@property (nonatomic, assign) NSInteger simulatorLaunchFailures;

@end

@implementation BPStats

+ (instancetype)sharedStats {
    static BPStats* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.applicationTime = [[BPStat alloc] init];
        self.applicationTime.startTime = [NSDate date];
        self.stats = [[NSMutableDictionary alloc] init];
        self.counters = [[NSMutableArray alloc] init];
        self.cleanRun = YES;
    }
    return self;
}

- (void)startTimer:(NSString *)name {
    [self startTimer:name atTime:[NSDate date]];
}

-(void)startTimer:(NSString *)name atTime:(NSDate *)date {
    BPStat *stat = [self statForName:name createIfNotExist:YES];
    stat.name = name;
    if (stat.startTime == nil) {
        stat.startTime = date;
    }
}

- (void)endTimer:(NSString *)name withResult:(NSString *) result {
    BPStat *stat = [self statForName:name createIfNotExist:NO];
    if (!stat) {
        [BPUtils printInfo:ERROR withString:@"EndTimerFailure: EndTimer called without starting a timer for '%@'", name];
#ifdef DEBUG
        [NSException raise:@"EndTimerFailure" format:@"EndTimer called without starting a timer for '%@'", name];
#endif
        return; // We'll just ignore it
    }
    stat.endTime = [NSDate date];
    stat.result = result;
}

- (void)addCounter:(NSString *)name withValues:(NSDictionary <NSString *, NSNumber *>*)counters {
    BPCounter *event = [[BPCounter alloc] init];
    event.name = name;
    event.timeStamp = [NSDate date];
    event.counters = counters;
    [self.counters addObject:event];
}

- (NSString *)getJsonStat:(NSString *)name {
    BPStat *stat = [self statForName:name createIfNotExist:NO];
    if (!stat) {
        [BPUtils printInfo:ERROR withString:@"OutputTimerState called without starting a timer for '%@'", name];
#ifdef DEBUG
        [NSException raise:@"OutputTimerFailure" format:@"OutputTimerState called without starting a timer for '%@'", name];
#endif
    }
    NSTimeInterval time = [stat.endTime timeIntervalSinceDate:stat.startTime];
    NSString *cname = [self resultToCname: stat.result];
    return [self completeEvent:stat.name
                           cat:stat.result
                            ts:[stat.startTime timeIntervalSince1970] * 1000000.0
                           dur:time * 1000000.0
                           arg:stat.result
                         cname:cname
            ];
}

- (BPStat *)statForName:(NSString *)name createIfNotExist:(BOOL)create {
    BPStat *stat = [self.stats valueForKey:name];
    if (!stat && create) {
        stat = [[BPStat alloc] init];
        [self.stats setObject:stat forKey:name];
    }
    return stat;
}

- (void)exitWithWriter:(BPWriter *)writer exitCode:(int)exitCode {
    self.applicationTime.endTime = [NSDate date];
    [self generateFullReportWithWriter:writer exitCode:exitCode];
}

- (void)addTest {
    self.testsTotal++;
}

- (void)addTestFailure {
    self.testFailures++;
}

- (void)addTestError {
    self.testErrors++;
}

- (void)addSimulatorCrash {
    self.simCrashes++;
}

- (void)addApplicationCrash {
    self.appCrashes++;
}

- (void)addRetry {
    self.retries++;
}

- (void)addTestRuntimeTimeout {
    self.runtimeTimeout++;
}

- (void)addTestOutputTimeout {
    self.outputTimeout++;
}

- (void)addSimulatorCreateFailure {
    self.simulatorCreateFailures++;
}

- (void)addSimulatorDeleteFailure {
    self.simulatorDeleteFailures++;
}

- (void)addSimulatorInstallFailure {
    self.simulatorInstallFailures++;
}

- (void)addSimulatorLaunchFailure {
    self.simulatorLaunchFailures++;
}

- (void)generateFullReportWithWriter:(BPWriter *)writer exitCode:(int)exitCode {
    unsigned long bundleID = [self bundleID];
    unsigned long bpNum = [self bpNum];
    // Metadata
    NSString *threadName = @"Bluepill";
    if (bundleID > 0) {
        threadName = [NSString stringWithFormat:@"BP Swimlane #%lu", bundleID];
    }
    [writer writeLine:[NSString stringWithFormat:@"{\"name\": \"thread_name\", \"ph\": \"M\", \"pid\": 1, \"tid\": %lu, \"args\": {\"name\": \"%@\"}},",
                       bundleID,
                       threadName
                       ]];

    [writer writeLine:[NSString stringWithFormat:@"{\"name\": \"thread_sort_index\", \"ph\": \"M\", \"pid\": 1, \"tid\": %lu, \"args\": {\"sort_index\": %lu}},",
                       bundleID,
                       bundleID
                       ]];

    NSString *bundleName = @"Bluepill";
    if (bpNum > 0) {
        bundleName = [NSString stringWithFormat:@"BP-%lu", bpNum];
    }
    NSString *name = [NSString stringWithFormat:@"%@ (%d)", bundleName, getpid()];
    [writer writeLine:[NSString stringWithFormat:@"%@,",
                       [self completeEvent:name
                                       cat:@"process"
                                        ts:[self.applicationTime.startTime timeIntervalSince1970] * 1000000.0
                                       dur:[self.applicationTime.endTime timeIntervalSinceDate:self.applicationTime.startTime] * 1000000.0
                                       arg:[NSString stringWithFormat:@"Exit Code %d", exitCode]
                                     cname:exitCode == 0 ? @"good" : @"bad"
                        ]]];


    NSMutableArray<NSString *> *allStatStrings = [[NSMutableArray alloc] init];

    // now output all the stats...
    for (NSString *name in self.stats) {
        [allStatStrings addObject:[self getJsonStat:name]];
    }
    // finally, print counters
    for (BPCounter *counter in self.counters) {
        NSMutableArray *args = [[NSMutableArray alloc] init];
        for (NSString *key in counter.counters) {
            [args addObject:[NSString stringWithFormat:@"\"%@\": %@", key, counter.counters[key]]];
        }
        [allStatStrings addObject:[NSString stringWithFormat:@"{\"name\":\"%@\", \"ph\": \"C\", \"ts\": \"%.0lf\", \"pid\": 1, \"args\": {%@}}",
                                   counter.name, [counter.timeStamp timeIntervalSince1970] * 1000000.0, [args componentsJoinedByString:@", "]]];
    }
    [writer writeLine:@"%@", [allStatStrings componentsJoinedByString:@",\n"]];
}

#pragma mark Trace Event Formatting

-(unsigned long)bundleID {
    char *s = getenv("_BP_INDEX");
    if (!s) {
        s = "0";
    }
    unsigned long bundleID = strtoul(s, 0, 10);
    return bundleID;
}

-(unsigned long)bpNum {
    char *s = getenv("_BP_NUM");
    if (!s) {
        s = "0";
    }
    unsigned long bpNum = strtoul(s, 0, 10);
    return bpNum;
}

- (NSString *)resultToCname:(NSString *)result {
    if ([result isEqualToString:@"PASSED"] || [result isEqualToString:@"BPExitStatusAllTestsPassed"]) {
        return @"good";
    } else if ([result isEqualToString:@"FAILED"] || [result isEqualToString:@"BPExitStatusTestsFailed"]) {
        return @"bad";
    } else if ([result isEqualToString:@"INFO"] || [result isEqualToString:@""]) {
        return @"";
    }
    return @"terrible";
}

- (NSString *)completeEvent:(NSString *)name cat:(NSString *)cat ts:(double)ts dur:(double)dur arg:(NSString *)argName cname:(NSString *)cname {
    NSString *cnameString = @"";
    if (cname && ![cname isEqualToString:@""]) {
        cnameString = [NSString stringWithFormat:@", \"cname\": \"%@\"", cname];
    }
    return [NSString stringWithFormat:@"{\"name\": \"%@\", \"cat\": \"%@\", \"ph\": \"X\", \"ts\": %.0lf, \"dur\": %.0lf, \"pid\": 1, \"tid\": %lu, \"args\": {\"name\": \"%@\"}%@}",
            name,
            cat,
            ts,
            dur,
            [self bundleID],
            argName,
            cnameString
            ];
}

@end

@implementation BPStat

@end

@implementation BPCounter

@end
