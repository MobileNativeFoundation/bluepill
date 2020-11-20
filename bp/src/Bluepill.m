//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "Bluepill.h"
#import "BPConfiguration.h"
#import "BPSimulator.h"
#import "BPTreeParser.h"
#import "BPReporters.h"
#import "BPWriter.h"
#import "BPStats.h"
#import "BPUtils.h"
#import "BPWaitTimer.h"
#import "BPExecutionContext.h"
#import "BPHandler.h"
#import <libproc.h>
#import "BPTestBundleConnection.h"
#import "BPTestDaemonConnection.h"
#import "BPXCTestFile.h"
#import <objc/runtime.h>

#define NEXT(x)     { [Bluepill setDiagnosticFunction:#x from:__FUNCTION__ line:__LINE__]; CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{ (x); }); }
#define NEXT_AFTER(delay, x) { \
    [Bluepill setDiagnosticFunction: #x from:__FUNCTION__ line:__LINE__]; \
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ (x); }); \
}

static int volatile interrupted = 0;

static void onInterrupt(int ignore) {
    interrupted = 1;
}

@interface Bluepill()<BPTestBundleConnectionDelegate>

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) BPConfiguration *executionConfigCopy;
@property (nonatomic, strong) BPExecutionContext *context;
@property (nonatomic, assign) BPExitStatus finalExitStatus;
@property (nonatomic, assign) BOOL exitLoop;
@property (nonatomic, assign) NSInteger failureTolerance;
@property (nonatomic, assign) NSInteger retries;

@property (nonatomic, assign) NSInteger maxCreateTries;
@property (nonatomic, assign) NSInteger maxInstallTries;

@end

@implementation Bluepill

- (instancetype)initWithConfiguration:(BPConfiguration *)config {
    if (self = [super init]) {
        self.config = config;
        unsigned int numProps = 0;
        objc_property_t *props = class_copyPropertyList([config class], &numProps);
        for (NSUInteger i = 0; i < numProps; ++i) {
            objc_property_t prop = props[i];
            NSString *propName = [[NSString alloc] initWithUTF8String:property_getName(prop)];
            [BPUtils printInfo:DEBUGINFO withString:@"[CONFIGURATION] %@: %@", propName, [config valueForKey:propName]];
        }
    }
    return self;
}

/**
 Kicks off the tests and loops until they're complete

 @return The exit status of the last execution of tests
 */
- (BPExitStatus)run {
    // Set up our SIGINT handler
    signal(SIGINT, onInterrupt);
    // Because failed tests are stored in the config so that they are not rerun,
    // We need to copy this here and any time we retry due to a test failure (not crash)
    self.executionConfigCopy = [self.config copy];

    // Save our failure tolerance because we're going to be changing this
    self.failureTolerance = [self.executionConfigCopy.failureTolerance integerValue];
    // Start the first attempt
    [self begin];

    // Wait for all attempts to complete, or an interruption
    while ([self continueRunning]) {
        if (interrupted) {
            [BPUtils printInfo:WARNING withString:@"Received interrupt (Ctrl-C). Please wait while cleaning up..."];
            [self deleteSimulatorWithContext:self.context andStatus:BPExitStatusInterrupted];
            break;
        }
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.01, NO);
    }

    // Tests completed or interruption received, show some quick stats as we exit
    [BPUtils printInfo:INFO withString:@"Number of Executions: %lu", self.retries + 1];
    [BPUtils printInfo:INFO withString:@"Final Exit Status: %@", [BPExitStatusHelper stringFromExitStatus:self.finalExitStatus]];
    return self.finalExitStatus;
}

- (void)begin {
    [self beginWithContext:nil];
}

- (void)beginWithContext:(BPExecutionContext *)context {

    // Create a context if no context specified. This will hold all of the data and objects for the current execution.
    if (!context) {
        [self createContext];
    }

    // Let's go
    NEXT([self setupExecutionWithContext:self.context]);
}

// Retry from the beginning (default) or failed tests only if onlyRetryFailed is true
- (void)retry {
    // There were test failures. Check if it can be retried.
    if (![self canRetryOnError] || self.failureTolerance <= 0) {
        // If there is no more retries, set the final exitCode to current context's exitCode
        self.finalExitStatus |= self.context.finalExitStatus;
        [BPUtils printInfo:ERROR withString:@"No retries left. Giving up."];
        [BPUtils printInfo:INFO withString:@"%s:%d finalExitStatus = %@", __FILE__, __LINE__, [BPExitStatusHelper stringFromExitStatus:self.finalExitStatus]];
        self.exitLoop = YES;
        return;
    }
    // Resetting the failed bit since the test is being retried
    self.context.finalExitStatus &= ~self.context.exitStatus;
    [self.context.parser cleanup];
    // Otherwise, reduce our failure tolerance count and retry
    self.failureTolerance -= 1;
    // If we're not retrying only failed tests, we need to get rid of our saved tests, so that we re-execute everything. Recopy config.
    if (self.executionConfigCopy.onlyRetryFailed == NO) {
        self.executionConfigCopy = [self.config copy];
    }

    // First increment the retry count
    self.retries += 1;

    // Log some useful information to the log
    [BPUtils printInfo:INFO withString:@"Exit Status: %@", [BPExitStatusHelper stringFromExitStatus:self.context.exitStatus]];
    [BPUtils printInfo:INFO withString:@"Failure Tolerance: %lu", self.failureTolerance];
    [BPUtils printInfo:INFO withString:@"Retry count: %lu", self.retries];

    // Then start again at the beginning
    [BPUtils printInfo:INFO withString:@"Retrying from scratch"];
    NEXT([self begin]);
}

// Recover from scratch if there is tooling failure, such as
//  - BPExitStatusSimulatorCreationFailed
//  - BPExitStatusSimulatorCrashed
//  - BPExitStatusInstallAppFailed
//  - BPExitStatusUninstallAppFailed
//  - BPExitStatusLaunchAppFailed
- (void)recover {
    // If error retry reach to the max, then return
    if (![self canRetryOnError]) {
        self.finalExitStatus |= self.context.finalExitStatus;
        [BPUtils printInfo:ERROR withString:@"No retries left. Giving up."];
        [BPUtils printInfo:INFO withString:@"%s:%d finalExitStatus = %@", __FILE__, __LINE__, [BPExitStatusHelper stringFromExitStatus:self.finalExitStatus]];
        self.exitLoop = YES;
        return;
    }

    [self.context.parser cleanup];
    // If we're not retrying only failed tests, we need to get rid of our saved tests, so that we re-execute everything. Recopy config.
    if (self.executionConfigCopy.onlyRetryFailed == NO) {
        self.executionConfigCopy = [self.config copy];
    }
    // Increment the retry count
    self.retries += 1;

    // Log some useful information to the log
    [BPUtils printInfo:INFO withString:@"Exit Status: %@", [BPExitStatusHelper stringFromExitStatus:self.context.exitStatus]];
    [BPUtils printInfo:INFO withString:@"Failure Tolerance: %lu", self.failureTolerance];
    [BPUtils printInfo:INFO withString:@"Retry count: %lu", self.retries];

    // Then start again from the beginning
    [BPUtils printInfo:INFO withString:@"Recovering from tooling problem"];
    NEXT([self begin]);
}

// Proceed to next test case
- (void)proceed {
    if (![self canRetryOnError]) {
        self.finalExitStatus |= self.context.finalExitStatus;
        [BPUtils printInfo:ERROR withString:@"No retries left. Giving up."];
        [BPUtils printInfo:INFO withString:@"%s:%d finalExitStatus = %@", __FILE__, __LINE__, [BPExitStatusHelper stringFromExitStatus:self.finalExitStatus]];
        self.exitLoop = YES;
        return;
    }
    self.retries += 1;
    [BPUtils printInfo:INFO withString:@"Exit Status: %@", [BPExitStatusHelper stringFromExitStatus:self.context.exitStatus]];
    [BPUtils printInfo:INFO withString:@"Failure Tolerance: %lu", self.failureTolerance];
    [BPUtils printInfo:INFO withString:@"Retry count: %lu", self.retries];
    self.context.attemptNumber = self.retries + 1; // set the attempt number
    self.context.exitStatus = BPExitStatusAllTestsPassed; // reset exitStatus

    [BPUtils printInfo:INFO withString:@"Proceeding to next test"];
    NEXT([self beginWithContext:self.context]);
}

- (void)createContext {
    BPExecutionContext *context = [[BPExecutionContext alloc] init];
    context.config = self.executionConfigCopy;
    context.config.cloneSimulator = self.config.cloneSimulator;
    context.config.templateSimUDID = self.config.templateSimUDID;
    NSError *error;
    NSString *testHostPath = context.config.testRunnerAppPath ?: context.config.appBundlePath;
    BPXCTestFile *xctTestFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:context.config.testBundlePath
                                                          andHostAppBundle:testHostPath
                                                                 withError:&error];
    NSAssert(xctTestFile != nil, @"Failed to load testcases from: %@; Error: %@", context.config.testBundlePath, [error localizedDescription]);
    context.config.allTestCases = [[NSArray alloc] initWithArray: xctTestFile.allTestCases];

    context.attemptNumber = self.retries + 1;
    self.context = context; // Store the context on self so that it's accessible to the interrupt handler in the loop
}

- (void)setupExecutionWithContext:(BPExecutionContext *)context {
    // Creates all of the objects we'll need for running the tests. Sets up logging, etc.

    [BPUtils printInfo:INFO withString:@"Running Tests. Attempt Number %lu.", context.attemptNumber];
    [BPStats sharedStats].attemptNumber = context.attemptNumber;

    NSString *simulatorLogPath;
    if (context.config.outputDirectory) {
        simulatorLogPath = [context.config.outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu-simulator.log", context.attemptNumber]];
    } else {
        NSError *err;
        NSString *tmpFileName = [BPUtils mkstemp:[NSString stringWithFormat:@"%@/%lu-bp-stdout-%u", NSTemporaryDirectory(), context.attemptNumber, getpid()]
                                       withError:&err];
        simulatorLogPath = tmpFileName? tmpFileName : [NSString stringWithFormat:@"/tmp/%lu-simulator.log", context.attemptNumber];
        if (err) {
            [BPUtils printInfo:ERROR withString:@"Error: %@\nLeaving log in %@", [err localizedDescription], simulatorLogPath];
        }
    }

    // This is the raw output from the simulator running tests
    BPWriter *simulatorWriter = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:simulatorLogPath];
    context.parser = [[BPTreeParser alloc] initWithWriter:simulatorWriter];

    if (context.attemptNumber == 1) {
        [context.parser cleanup];
    }

    context.runner = [self createSimulatorRunnerWithContext:context];

    // Set up retry counts.
    self.maxCreateTries = [self.config.maxCreateTries integerValue];
    self.maxInstallTries = [self.config.maxInstallTries integerValue];
    
    if (context.config.deleteSimUDID) {
        NEXT([self deleteSimulatorOnlyTaskWithContext:context]);
    } else {
        NEXT([self createSimulatorWithContext:context]);
    }
}

- (BPSimulator *)createSimulatorRunnerWithContext:(BPExecutionContext *)context {
    return [BPSimulator simulatorWithConfiguration:context.config];
}

- (void)createSimulatorWithContext:(BPExecutionContext *)context {
    NSString *stepName;
    if (self.config.cloneSimulator) {
        stepName = CLONE_SIMULATOR(context.attemptNumber);
    } else {
        stepName = CREATE_SIMULATOR(context.attemptNumber);
    }
    NSDate *simStart = [NSDate date];
    NSString *deviceName = [NSString stringWithFormat:@"BP%d-%lu-%lu", getpid(), context.attemptNumber, self.maxCreateTries];

    __weak typeof(self) __self = self;
    [[BPStats sharedStats] startTimer:stepName];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.createTimeout doubleValue]];
    [timer start];

    BPCreateSimulatorHandler *handler = [BPCreateSimulatorHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [[BPStats sharedStats] endTimer:stepName withResult:__handler.error ? @"ERROR" : @"INFO"];
        [BPUtils printInfo:(__handler.error ? ERROR : INFO)
                withString:@"Completed: %@ %@", stepName, context.runner.UDID];
    };

    handler.onSuccess = ^{
        [[BPStats sharedStats] startTimer:SIMULATOR_LIFETIME(context.runner.UDID) atTime:simStart];
        if (self.config.scriptFilePath) {
            [context.runner runScriptFile:self.config.scriptFilePath];
        }
        if (self.config.cloneSimulator) {
            // launch application directly when clone simulator
            NEXT([__self launchApplicationWithContext:context]);
        } else {
            // Install application when test without clone
            NEXT([__self installApplicationWithContext:context]);
        };
    };

    handler.onError = ^(NSError *error) {
        [[BPStats sharedStats] addSimulatorCreateFailure];
        [BPUtils printInfo:ERROR withString:@"%@", [error localizedDescription]];
        // If we failed to create the simulator, there's no reason for us to try to delete it, which can just cause more issues
        if (--__self.maxCreateTries > 0) {
            [BPUtils printInfo:INFO withString:@"Relaunching the simulator due to a BAD STATE"];
            [__self deleteSimulatorWithContext:context completion:^{
                context.runner = [__self createSimulatorRunnerWithContext:context];
                NEXT([__self createSimulatorWithContext:context]);
            }];
        } else {
            NEXT([__self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorCreationFailed]);
        }
    };

    handler.onTimeout = ^{
        [[BPStats sharedStats] addSimulatorCreateFailure];
        [[BPStats sharedStats] endTimer:stepName withResult:@"TIMEOUT"];
        [BPUtils printInfo:ERROR withString:@"Timeout: %@", stepName];
    };

    if (self.config.cloneSimulator) {
        [context.runner cloneSimulatorWithDeviceName:deviceName completion:handler.defaultHandlerBlock];
    } else {
        [context.runner createSimulatorWithDeviceName:deviceName completion:handler.defaultHandlerBlock];
    }
}

- (void)installApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = INSTALL_APPLICATION(context.attemptNumber);
    [[BPStats sharedStats] startTimer:stepName];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    NSError *error = nil;
    BOOL success = [context.runner installApplicationWithError:&error];

    __weak typeof(self) __self = self;
    [[BPStats sharedStats] endTimer:stepName withResult:success? @"INFO": @"ERROR"];
    [BPUtils printInfo:(success ? INFO : ERROR) withString:@"Completed: %@", stepName];

    if (!success) {
        [[BPStats sharedStats] addSimulatorInstallFailure];
        [BPUtils printInfo:ERROR withString:@"Could not install app in simulator: %@", [error localizedDescription]];
        if (--__self.maxInstallTries > 0) {
            if ([[error description] containsString:@"Booting"]) {
                [BPUtils printInfo:INFO withString:@"Simulator is still booting. Will defer install for 1 minute."];
                // The simulator is still booting, wait for 1 minute before trying again
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 60, NO); // spin the runloop while we wait
                // Try to install again
                NEXT([__self installApplicationWithContext:context]);
            } else {
                // If it is another error, relaunch the simulator
                [BPUtils printInfo:INFO withString:@"Relaunching the simulator due to a BAD STATE"];
                context.runner = [__self createSimulatorRunnerWithContext:context];
                NEXT([__self createSimulatorWithContext:context]);
            }
        } else {
            NEXT([__self deleteSimulatorWithContext:context andStatus:BPExitStatusInstallAppFailed]);
        }
        return;
    } else {
        NEXT([self launchApplicationWithContext:context]);
    }
}

- (void)uninstallApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = UNINSTALL_APPLICATION(context.attemptNumber);
    [[BPStats sharedStats] startTimer:stepName];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    NSError *error = nil;
    BOOL success = [context.runner uninstallApplicationWithError:&error];

    [[BPStats sharedStats] endTimer:stepName withResult:success ? @"INFO" : @"ERROR"];
    [BPUtils printInfo:(success ? INFO : ERROR) withString:@"Completed: %@", stepName];

    if (!success) {
        [[BPStats sharedStats] addSimulatorInstallFailure];
        [BPUtils printInfo:ERROR withString:@"Could not uninstall app in simulator: %@", [error localizedDescription]];
        NEXT([self deleteSimulatorWithContext:context andStatus:BPExitStatusUninstallAppFailed]);
    } else {
        NEXT([self installApplicationWithContext:context]);
    }
}

- (void)launchApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = LAUNCH_APPLICATION(context.attemptNumber);
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    [[BPStats sharedStats] startTimer:LAUNCH_APPLICATION(context.attemptNumber)];

    __weak typeof(self) __self = self;

    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.launchTimeout doubleValue]];
    [timer start];

    BPApplicationLaunchHandler *handler = [BPApplicationLaunchHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [BPUtils printInfo:((__handler.pid > -1) ? INFO : ERROR) withString:@"Completed: %@", stepName];
    };

    handler.onSuccess = ^{
        context.pid = __handler.pid;
        NEXT([__self connectTestBundleAndTestDaemonWithContext:context]);
    };

    handler.onError = ^(NSError *error) {
        [[BPStats sharedStats] endTimer:LAUNCH_APPLICATION(context.attemptNumber) withResult:@"ERROR"];
        [BPUtils printInfo:ERROR withString:@"Could not launch app and tests: %@", [error localizedDescription]];
        NEXT([__self deleteSimulatorWithContext:context andStatus:BPExitStatusLaunchAppFailed]);
    };

    handler.onTimeout = ^{
        [[BPStats sharedStats] addSimulatorLaunchFailure];
        [[BPStats sharedStats] endTimer:LAUNCH_APPLICATION(context.attemptNumber) withResult:@"TIMEOUT"];
        [BPUtils printInfo:FAILED withString:@"Timeout: %@", stepName];
    };

    [context.runner launchApplicationAndExecuteTestsWithParser:context.parser andCompletion:handler.defaultHandlerBlock];
}

- (void)connectTestBundleAndTestDaemonWithContext:(BPExecutionContext *)context {
    if (context.isTestRunnerContext) {
        // If the isTestRunnerContext is flipped on, don't connect testbundle again.
        return;
    }
    BPTestBundleConnection *bConnection = [[BPTestBundleConnection alloc] initWithContext:context andInterface:self];
    bConnection.simulator = context.runner;
    bConnection.config = self.config;

    BPTestDaemonConnection *dConnection = [[BPTestDaemonConnection alloc] initWithDevice:context.runner andInterface:nil];
    dConnection.testRunnerPid = context.pid;
    [dConnection connectWithTimeout:180];
    [bConnection connectWithTimeout:180];
    [bConnection startTestPlan];
    NEXT([self checkProcessWithContext:context]);

}
- (void)checkProcessWithContext:(BPExecutionContext *)context {
    BOOL isRunning = [self isProcessRunningWithContext:context];
    if (!isRunning && [context.runner isFinished]) {
        [BPUtils printInfo:INFO withString:@"Finished"];
        [[BPStats sharedStats] endTimer:LAUNCH_APPLICATION(context.attemptNumber) withResult:[BPExitStatusHelper stringFromExitStatus:context.exitStatus]];
        [self runnerCompletedWithContext:context];
        return;
    }
    if (![context.runner isSimulatorRunning]) {
        [[BPStats sharedStats] endTimer:LAUNCH_APPLICATION(context.attemptNumber) withResult:@"SIMULATOR CRASHED"];
        [BPUtils printInfo:ERROR withString:@"SIMULATOR CRASHED!!!"];
        context.simulatorCrashed = YES;
        [[BPStats sharedStats] addSimulatorCrash];
        [self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorCrashed];
        return;
    }

    // This check should be last after all of the more specific tests
    // It checks if the app is even running, which it must be at this point
    // If it's not running and we passed the above checks (e.g., the tests are not yet completed)
    // then it must mean the app has crashed.
    // However, we have a short-circuit for tests because those may not actually run any app
    if (!isRunning && context.pid > 0 && [context.runner isApplicationLaunched] && !self.config.testing_NoAppWillRun) {
        // The tests ended before they even got started or the process is gone for some other reason
        [[BPStats sharedStats] endTimer:LAUNCH_APPLICATION(context.attemptNumber) withResult:@"APP CRASHED"];
        [BPUtils printInfo:ERROR withString:@"Application crashed!"];
        [[BPStats sharedStats] addApplicationCrash];
        [self deleteSimulatorWithContext:context andStatus:BPExitStatusAppCrashed];
        return;
    }

    NEXT_AFTER(1, [self checkProcessWithContext:context]);
}

- (BOOL)isProcessRunningWithContext:(BPExecutionContext *)context {
    if (self.config.testing_NoAppWillRun) {
        return NO;
    }
    NSAssert(context.pid > 0, @"Application PID must be > 0");
    int rc = kill(context.pid, 0);
    return (rc == 0);
}

- (void)runnerCompletedWithContext:(BPExecutionContext *)context {
    [context.parser completed];

    if (context.simulatorCrashed == NO && context.config.outputDirectory) {
        NSString *fileName = [NSString stringWithFormat:@"TEST-%@-%lu-results.xml",
                              [[context.config.testBundlePath lastPathComponent] stringByDeletingPathExtension],
                              (long)context.attemptNumber];
        NSString *outputFile = [context.config.outputDirectory stringByAppendingPathComponent:fileName];

        [BPUtils printInfo:INFO withString:@"Writing JUnit report to: %@", outputFile];
        BPWriter *junitLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
        [junitLog writeLine:@"%@", [context.parser generateLog:[[JUnitReporter alloc] init]]];
        [context.parser cleanup];
    }

    if (context.simulatorCrashed) {
        // If we crashed, we need to retry
        [self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorCrashed];
    } else if (self.config.keepSimulator
               && (context.runner.exitStatus == BPExitStatusAllTestsPassed
                || context.runner.exitStatus == BPExitStatusTestsFailed)) {
      context.exitStatus = [context.runner exitStatus];
      NEXT([self finishWithContext:context]);
    } else {
      // If the tests failed, save as much debugging info as we can. XXX: Put this behind a flag
      if (context.runner.exitStatus != BPExitStatusAllTestsPassed && _config.saveDiagnosticsOnError) {
        [BPUtils printInfo:INFO withString:@"Saving Diagnostics for Debugging"];
        [BPUtils saveDebuggingDiagnostics:_config.outputDirectory];
      }
      
      [self deleteSimulatorWithContext:context andStatus:[context.runner exitStatus]];
    }
}

- (void)deleteSimulatorWithContext:(BPExecutionContext *)context andStatus:(BPExitStatus)status {
    context.exitStatus = status;
    __weak typeof(self) __self = self;
    
    [self deleteSimulatorWithContext:context completion:^{
        NEXT([__self finishWithContext:context]);
    }];
}

- (void)deleteSimulatorWithContext:(BPExecutionContext *)context completion:(void (^)(void))completion {
    NSString *simUDID = context.runner.UDID;
    NSString *stepName = DELETE_SIMULATOR(context.attemptNumber);
    [[BPStats sharedStats] startTimer:stepName];
    [BPUtils printInfo:INFO withString:@"%@", stepName];
    
    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.deleteTimeout doubleValue]];
    [timer start];

    BPDeleteSimulatorHandler *handler = [BPDeleteSimulatorHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [[BPStats sharedStats] endTimer:stepName withResult:__handler.error?@"ERROR":@"INFO"];
        [BPUtils printInfo:(__handler.error ? ERROR : INFO) withString:@"Completed: %@ %@", stepName, context.runner.UDID];
    };

    handler.onSuccess = ^{
        [[BPStats sharedStats] endTimer:SIMULATOR_LIFETIME(simUDID) withResult:@"INFO"];
        completion();
    };

    handler.onError = ^(NSError *error) {
        [[BPStats sharedStats] addSimulatorDeleteFailure];
        [BPUtils printInfo:ERROR withString:@"%@", [error localizedDescription]];
        completion();
    };

    handler.onTimeout = ^{
        [[BPStats sharedStats] addSimulatorDeleteFailure];
        [[BPStats sharedStats] endTimer:stepName withResult:@"TIMEOUT"];
        [BPUtils printInfo:ERROR
                withString:@"Timeout: %@", stepName];
        completion();
    };

    [context.runner deleteSimulatorWithCompletion:handler.defaultHandlerBlock];
}

// Only called when bp is running in the delete only mode.
- (void)deleteSimulatorOnlyTaskWithContext:(BPExecutionContext *)context {
    
    if ([context.runner useSimulatorWithDeviceUDID: [[NSUUID alloc] initWithUUIDString:context.config.deleteSimUDID]]) {
        NEXT([self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorDeleted]);
    } else {
        [BPUtils printInfo:ERROR withString:@"Failed to reconnect to simulator %@", context.config.deleteSimUDID];
        context.exitStatus = BPExitStatusSimulatorReuseFailed;
        
        NEXT([self finishWithContext:context]);
    }
}

/**
 Scenarios:
 1. crash and proceed passes -> Crash
 2. time out and retry passes -> AllPass
 3. failure and retry passes -> AllPass
 4. happy all pass -> AllPassed
 5. failure and still fails -> TestFailed
 */
- (void)finishWithContext:(BPExecutionContext *)context {
    context.finalExitStatus |= context.exitStatus;
    [BPUtils printInfo:INFO withString:@"Attempt's Exit Status: %@, Bundle exit status: %@",
     [BPExitStatusHelper stringFromExitStatus:context.exitStatus],
     [BPExitStatusHelper stringFromExitStatus:context.finalExitStatus]];

    switch (context.exitStatus) {
        // BP exit handler
        case BPExitStatusInterrupted:
            self.exitLoop = YES;
            return;

        // If there is no test crash/time out, we retry from scratch
        case BPExitStatusTestsFailed:
            NEXT([self retry]);
            return;

        case BPExitStatusAllTestsPassed:
            // Time to exit
            self.finalExitStatus |= BPExitStatusAllTestsPassed;
            self.exitLoop = YES;
            return;

        // Recover from scratch if there is tooling failure.
        case BPExitStatusSimulatorCreationFailed:
        case BPExitStatusSimulatorCrashed:
        case BPExitStatusInstallAppFailed:
        case BPExitStatusUninstallAppFailed:
        case BPExitStatusLaunchAppFailed:
            NEXT([self recover]);
            return;

        // If it is test hanging or crashing, we set final exit code of current context and proceed.
        case BPExitStatusTestTimeout:
            if (!self.config.onlyRetryFailed) {
                self.finalExitStatus |= context.exitStatus;
            }
            NEXT([self proceed]);
            return;

        case BPExitStatusAppCrashed:
            if (!self.config.retryAppCrashTests) {
                // Crashed test is considered fatal when retry is disabled
                self.finalExitStatus |= context.exitStatus;
            }
            NEXT([self proceed]);
            return;

        case BPExitStatusSimulatorDeleted:
        case BPExitStatusSimulatorReuseFailed:
            self.finalExitStatus |= context.finalExitStatus;
            [BPUtils printInfo:INFO withString:@"%s:%d finalExitStatus = %@",
             __FILE__, __LINE__,
             [BPExitStatusHelper stringFromExitStatus:self.finalExitStatus]];
            self.exitLoop = YES;
            return;
    }
    [BPUtils printInfo:ERROR withString:@"%s:%d YOU SHOULDN'T BE HERE. exitStatus = %@, finalExitStatus = %@",
     __FILE__, __LINE__,
     [BPExitStatusHelper stringFromExitStatus:context.exitStatus],
     [BPExitStatusHelper stringFromExitStatus:context.finalExitStatus]];
}

// MARK: Helpers

- (BOOL)continueRunning {
    return (self.exitLoop == NO);
}

- (NSString *)test_simulatorUDID {
    return self.context.runner.UDID;
}

- (BPSimulator *)test_simulator {
    return self.context.runner;
}

- (BOOL)canRetryOnError {
    NSInteger maxErrorRetryCount = [self.config.errorRetriesCount integerValue];
    if (self.retries < maxErrorRetryCount) {
        return true;
    }
    
    if (self.retries > maxErrorRetryCount) {
        // If retries strictly exceeds the max error retry, then we must have incremented it beyond the limit somehow.
        // It is safe to halt retries here, but log to alert unexpected behavior.
        [BPUtils printInfo:ERROR withString:@"Current retry count (%d) exceeded maximum retry count (%d)!",
         (int) self.retries,
         (int) maxErrorRetryCount];
    }
    return false;
}

int __line;
NSString *__function;
NSString *__from;

+ (void)setDiagnosticFunction:(const char *)function from:(const char *)from line:(int)line {
    __function = [NSString stringWithCString:function encoding:NSUTF8StringEncoding];
    __from = [NSString stringWithCString:from encoding:NSUTF8StringEncoding];
    __line = line;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"Currently executing %@: Line %d (Invoked by: %@)", __function, __line, __from];
}

#pragma mark - BPTestBundleConnectionDelegate
- (void)_XCT_launchProcessWithPath:(NSString *)path bundleID:(NSString *)bundleID arguments:(NSArray *)arguments environmentVariables:(NSDictionary *)environment {
    self.context.isTestRunnerContext = YES;
    [self installApplicationWithContext:self.context];
}

@end
