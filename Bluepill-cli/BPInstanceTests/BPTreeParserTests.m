//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPConfiguration.h"
#import "BPWriter.h"
#import "BPTreeParser.h"
#import "SimulatorMonitor.h"
#import "BPExitStatus.h"
#import "BPStats.h"
#import "BPReporters.h"
#import "BPUtils.h"

@interface BPTreeParserTests : XCTestCase

@property (nonatomic, strong) BPConfiguration* config;

@end

@implementation BPTreeParserTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
    [BPUtils enableDebugOutput:![BPUtils isBuildScript]];
    self.config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    self.config.testing_NoAppWillRun = YES;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

BPWriter *getWriter() {
    BPWriter *writer;
    if ([BPUtils isBuildScript]) {
        NSString *tmpPath = [BPUtils mkstemp:@"out" withError:nil];
        writer = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:tmpPath];
    } else {
        writer = [[BPWriter alloc] initWithDestination:BPWriterDestinationStdout];
    }
    return writer;
}

- (void)testParsingCrash {
    NSString *logPath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"parse_crash.log"];
    NSString *wholeFile = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];

    BPWriter *writer = getWriter();
    BPTreeParser *parser = [[BPTreeParser alloc] initWithWriter:writer];
    SimulatorMonitor *monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];

    parser.delegate = monitor;

    [BPStats sharedStats].attemptNumber = 1;

    [parser handleChunkData:[wholeFile dataUsingEncoding:NSUTF8StringEncoding]];
    [parser completed];
    [parser completedFinalRun];

    if (![BPUtils isBuildScript]) {
        NSLog(@">>>>>>>>> %@ <<<<<<<<<<<", [BPExitStatusHelper stringFromExitStatus:monitor.exitStatus]);
    }
    XCTAssert(monitor.exitStatus == BPExitStatusAppCrashed);
}

- (void)testCrashIntermixedWithPass {
    NSString *logPath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"intermixed_crash.log"];
    NSString *wholeFile = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    
    BPWriter *writer = getWriter();
    BPTreeParser *parser = [[BPTreeParser alloc] initWithWriter:writer];
    SimulatorMonitor *monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];

    parser.delegate = monitor;

    [BPStats sharedStats].attemptNumber = 1;

    [parser handleChunkData:[wholeFile dataUsingEncoding:NSUTF8StringEncoding]];
    [parser completed];
    [parser completedFinalRun];

    if (![BPUtils isBuildScript]) {
        NSLog(@">>>>>>>>> %@ <<<<<<<<<<<", [BPExitStatusHelper stringFromExitStatus:monitor.exitStatus]);
    }
    XCTAssert(monitor.exitStatus == BPExitStatusAppCrashed);
}

- (void)testBadFilenameParsing {
    NSString *logPath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"badfilename.log"];
    NSString *wholeFile = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    
    BPWriter *writer = getWriter();
    BPTreeParser *parser = [[BPTreeParser alloc] initWithWriter:writer];
    SimulatorMonitor *monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];

    parser.delegate = monitor;

    [BPStats sharedStats].attemptNumber = 1;

    [parser handleChunkData:[wholeFile dataUsingEncoding:NSUTF8StringEncoding]];
    [parser completed];
    [parser completedFinalRun];

    if (![BPUtils isBuildScript]) {
        NSLog(@">>>>>>>>> %@ <<<<<<<<<<<", [BPExitStatusHelper stringFromExitStatus:monitor.exitStatus]);
    }
    XCTAssert(monitor.exitStatus == BPExitStatusAppCrashed);
}

- (void)testMissedCrash {
    NSString *logPath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"missed-crash.log"];
    NSString *wholeFile = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    
    BPWriter *writer = getWriter();
    BPTreeParser *parser = [[BPTreeParser alloc] initWithWriter:writer];
    SimulatorMonitor *monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];
    monitor.maxTimeWithNoOutput = 2.0; // change the max output time to 2 seconds

    parser.delegate = monitor;

    [BPStats sharedStats].attemptNumber = 1;

    [parser handleChunkData:[wholeFile dataUsingEncoding:NSUTF8StringEncoding]];
    // Sleep long enough to generate a timeout
    CFRunLoopRunInMode(kCFRunLoopDefaultMode, 3.0, NO);

    [parser completed];
    [parser completedFinalRun];

    if (![BPUtils isBuildScript]) {
        NSLog(@"%@", [parser generateLog:[[JUnitReporter alloc] init]]);

        NSLog(@">>>>>>>>> %@ <<<<<<<<<<<", [BPExitStatusHelper stringFromExitStatus:monitor.exitStatus]);
    }
    XCTAssert(monitor.exitStatus == BPExitStatusAppCrashed);
}

- (void)testErrorOnlyCrash {
    NSString *logPath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"error_only_crash.log"];
    NSString *wholeFile = [NSString stringWithContentsOfFile:logPath encoding:NSUTF8StringEncoding error:nil];
    
    BPWriter *writer = getWriter();
    BPTreeParser *parser = [[BPTreeParser alloc] initWithWriter:writer];
    SimulatorMonitor *monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];

    parser.delegate = monitor;

    [BPStats sharedStats].attemptNumber = 1;

    [parser handleChunkData:[wholeFile dataUsingEncoding:NSUTF8StringEncoding]];
    [parser completed];
    [parser completedFinalRun];

    if (![BPUtils isBuildScript]) {
        NSLog(@">>>>>>>>> %@ <<<<<<<<<<<", [BPExitStatusHelper stringFromExitStatus:monitor.exitStatus]);
    }
    XCTAssert(monitor.exitStatus == BPExitStatusAppCrashed);
}

@end
