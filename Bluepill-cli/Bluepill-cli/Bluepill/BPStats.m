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
#import "BPExitStatus.h"

@interface BPStat : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, assign) float duration;
@property (nonatomic, strong) NSString *errorMessage;
@property (nonatomic, assign) NSInteger attemptNum;

@end

@interface BPStats()

@property (nonatomic, strong) NSMutableArray *stats;
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
@property (nonatomic, assign) NSInteger simulatorReuseFailures;

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
        self.stats = [[NSMutableArray alloc] init];
        self.cleanRun = YES;
    }
    return self;
}

- (void)startTimer:(NSString *)name {
    [self startTimer:name withAttemptNumber:0];
}

- (void)startTimer:(NSString *)name withAttemptNumber:(NSInteger)attemptNumber {
    BPStat *stat = [self statForName:name createIfNotExist:YES];
    stat.name = name;
    if (stat.startTime == nil) {
        stat.startTime = [NSDate date];
    }
    stat.attemptNum = attemptNumber;
}


- (void)endTimer:(NSString *)name withErrorMessage:(NSString *)errorMessage {
    BPStat *stat = [self statForName:name createIfNotExist:NO];
    if (!stat) {
        fprintf(stderr, "EndTimerFailure: EndTimer called without starting a timer for '%s'\n", [name UTF8String]);
        if ([self.stats count] == 1) {
            fprintf(stderr, "There is only one stat remaining to be closed, '%s'\n", [[self.stats.firstObject name] UTF8String]);
            stat = self.stats.firstObject;
            fprintf(stderr, "Will close with '%s' instead.\n", [stat.name UTF8String]);
        }
#ifdef DEBUG
        [NSException raise:@"EndTimerFailure" format:@"EndTimer called without starting a timer for '%@'", name];
#endif
        if (!stat) {
            return; // We'll just ignore it
        }
    }
    stat.endTime = [NSDate date];
    stat.errorMessage = [[NSString alloc] initWithString:errorMessage];
    stat.duration = [stat.endTime timeIntervalSinceDate:stat.startTime];
}


- (void)outputTimerStats:(NSString *)name toWriter:(BPWriter *)writer {
    BPStat *stat = [self statForName:name createIfNotExist:NO];
    if (!stat) {
        fprintf(stderr, "OutputTimerState called without starting a timer for '%s'\n", [name UTF8String]);
#ifdef DEBUG
        [NSException raise:@"OutputTimerFailure" format:@"OutputTimerState called without starting a timer for '%@'", name];
#endif
    }
    NSTimeInterval time = [stat.endTime timeIntervalSinceDate:stat.startTime];
    [writer writeLine:@"%@ %f seconds", [[name stringByAppendingString:@":"] stringByPaddingToLength:60 withString:@" " startingAtIndex:0], time];
}

- (BPStat *)statForName:(NSString *)name createIfNotExist:(BOOL)create {
    BPStat *stat = nil;
    for (BPStat *s in self.stats) {
        if ([s.name isEqualToString:name]) {
            stat = s;
            break;
        }
    }
    if (!stat && create) {
        stat = [[BPStat alloc] init];
        [self.stats addObject:stat];
    }
    return stat;
}

- (void)exitWithWriter:(BPWriter *)writer exitCode:(int)exitCode andCreateFullReport:(BOOL)fullReport {
    self.applicationTime.endTime = [NSDate date];
    if (!fullReport) {
        [self outputTimerStats:@"Application Time" toWriter:writer];
    } else {
        [self generateFullReportWithWriter:writer exitCode:exitCode];
    }
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

- (void)addSimulatorReuseFailure {
    self.simulatorReuseFailures++;
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


- (void)generateCSVreportWithPath:(NSString *)path {
    NSMutableString *csvString = [[NSMutableString alloc]initWithCapacity:0];
    [csvString appendString:@"AttemptNum, EventName, Duration, FinalStatus, TimeStamp"];
    for (BPStat *stat in self.stats) {
        [csvString appendString:[NSString stringWithFormat:@"\n%ld, %@, %f, %@, %@", stat.attemptNum, stat.name, stat.duration, stat.errorMessage, stat.startTime]];
    }
    [csvString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


- (void)generateFullReportWithWriter:(BPWriter *)writer exitCode:(int)exitCode {
    [writer writeLine:@"--------------"];
    [writer writeLine:@"Run Statistics"];
    [writer writeLine:@"--------------"];
    [writer writeLine:@"Start Time:           %@", self.applicationTime.startTime];
    [writer writeLine:@"End Time:             %@", self.applicationTime.endTime];
    [writer writeLine:@"Total execution time: %f seconds", [self.applicationTime.endTime timeIntervalSinceDate:self.applicationTime.startTime]];

    [writer writeLine:@""];
    [writer writeLine:@"Times Taken"];
    [writer writeLine:@"-----------"];
    for (BPStat *stat in self.stats) {
        [self outputTimerStats:stat.name toWriter:writer];
    }

    [writer writeLine:@""];
    [writer writeLine:@"Summary"];
    [writer writeLine:@"-------"];
    [writer writeLine:@"Total Tests Executed:           %d", self.testsTotal];
    [writer writeLine:@"Failed Tests (includes errors): %d", self.testFailures];
    [writer writeLine:@"Error Tests:                    %d", self.testErrors];
    [writer writeLine:@"Timeout due to test run-time:   %d", self.runtimeTimeout];
    [writer writeLine:@"Timeout due to no output:       %d", self.outputTimeout];
    [writer writeLine:@"Retries:                        %d", self.retries];
    [writer writeLine:@"Application Crashes:            %d", self.appCrashes];
    [writer writeLine:@"Simulator Crashes:              %d", self.simCrashes];
    [writer writeLine:@"Simulator Creation Failures:    %d", self.simulatorCreateFailures];
    [writer writeLine:@"Simulator Deletion Failures:    %d", self.simulatorDeleteFailures];
    [writer writeLine:@"App Install Failures:           %d", self.simulatorInstallFailures];
    [writer writeLine:@"App Launch Failures:            %d", self.simulatorLaunchFailures];
    [writer writeLine:@"App Launch Failures:            %d", self.simulatorReuseFailures];

    [writer writeLine:@""];
    [writer writeLine:@"Exit Code: %d", exitCode];
    [writer writeLine:@""];
}

@end

@implementation BPStat

@end
