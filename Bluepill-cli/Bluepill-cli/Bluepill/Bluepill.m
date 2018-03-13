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

void onInterrupt(int ignore) {
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
@property (nonatomic, assign) BOOL reuseSimAllowed;

@property (nonatomic, assign) NSInteger maxCreateTries;
@property (nonatomic, assign) NSInteger maxInstallTries;
@property (nonatomic, assign) NSInteger maxLaunchTries;

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

    self.reuseSimAllowed = YES;

    // Connect to test manager daemon and test bundle

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

    if (self.config.keepSimulator) {
        [self writeSimUDIDFile];
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
    // There were test failures. If our failure tolerance is 0, then we're good with that.
    if (self.failureTolerance == 0) {
        // If there is no more retries, set the final exitCode to current context's exitCode
        if (self.context.exitStatus != BPExitStatusTestsAllPassed) {
            self.finalExitStatus = self.context.exitStatus;
        } else {
            self.finalExitStatus = self.context.finalExitStatus;
        }
        self.exitLoop = YES;
        return;
    }
    [self.context.parser cleanup];
    // Otherwise, reduce our failure tolerance count and retry
    self.failureTolerance -= 1;
    // If we're not retrying only failed tests, we need to get rid of our saved tests, so that we re-execute everything. Recopy config.
    if (self.executionConfigCopy.onlyRetryFailed == NO) {
        self.executionConfigCopy = [self.config copy];
        [BPUtils printInfo:WARNING withString:@"onlyRetryFailed is set to NO!"];
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
  if (self.retries == [self.config.errorRetriesCount integerValue]) {
      if (self.context.exitStatus != BPExitStatusTestsAllPassed) {
          self.finalExitStatus = self.context.exitStatus;
      } else {
          self.finalExitStatus = self.context.finalExitStatus;
      }      self.exitLoop = YES;
      [BPUtils printInfo:ERROR withString:@"Too many retries have occurred. Giving up."];
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
    if (self.retries == [self.config.errorRetriesCount integerValue]) {
        if (self.context.exitStatus != BPExitStatusTestsAllPassed) {
            self.finalExitStatus = self.context.exitStatus;
        } else {
            self.finalExitStatus = self.context.finalExitStatus;
        }        self.exitLoop = YES;
        [BPUtils printInfo:ERROR withString:@"Too many retries have occurred. Giving up."];
        return;
    }
    self.retries += 1;
    [BPUtils printInfo:INFO withString:@"Exit Status: %@", [BPExitStatusHelper stringFromExitStatus:self.context.exitStatus]];
    [BPUtils printInfo:INFO withString:@"Failure Tolerance: %lu", self.failureTolerance];
    [BPUtils printInfo:INFO withString:@"Retry count: %lu", self.retries];
    self.context.attemptNumber = self.retries + 1; // set the attempt number
    self.context.exitStatus = BPExitStatusTestsAllPassed; // reset exitStatus
    [BPUtils printInfo:INFO withString:@"Proceeding to next test"];
    NEXT([self beginWithContext:self.context]);
}

- (void)createContext {
    BPExecutionContext *context = [[BPExecutionContext alloc] init];
    context.config = self.executionConfigCopy;
    NSError *error;
    NSString *testHostPath = context.config.testRunnerAppPath ?: context.config.appBundlePath;
    BPXCTestFile *xctTestFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:context.config.testBundlePath
                                                          andHostAppBundle:testHostPath
                                                                 withError:&error];
    NSAssert(xctTestFile != nil, @"Failed to load testcases from %@", [error localizedDescription]);
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
        simulatorLogPath = [context.config.outputDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"attempt_%lu-simulator.log", context.attemptNumber]];
    } else {
        NSError *err;
        NSString *tmpFileName = [BPUtils mkstemp:[NSString stringWithFormat:@"%@/%lu-bp-stdout-%u", NSTemporaryDirectory(), context.attemptNumber, getpid()]
                                       withError:&err];
        simulatorLogPath = tmpFileName;
        if (!tmpFileName) {
            simulatorLogPath = [NSString stringWithFormat:@"/tmp/attempt_%lu-simulator.log", context.attemptNumber];
            [BPUtils printInfo:ERROR withString:@"ERROR: %@\nLeaving log in %@", [err localizedDescription], simulatorLogPath];
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
    self.maxLaunchTries = [self.config.maxLaunchTries integerValue];
    
    if (context.config.deleteSimUDID) {
        NEXT([self deleteSimulatorOnlyTaskWithContext:context]);
    } else if (context.config.useSimUDID && self.reuseSimAllowed) {
        NEXT([self reuseSimulatorWithContext:context]);
    } else {
        NEXT([self createSimulatorWithContext:context]);
    }
}

- (BPSimulator *)createSimulatorRunnerWithContext:(BPExecutionContext *)context {
    return [BPSimulator simulatorWithConfiguration:context.config];
}

- (void)createSimulatorWithContext:(BPExecutionContext *)context {
    NSString *stepName = CREATE_SIMULATOR(context.attemptNumber);
    NSString *deviceName = [NSString stringWithFormat:@"BP%d-%lu-%lu", getpid(), context.attemptNumber, self.maxCreateTries];

    __weak typeof(self) __self = self;
    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.createTimeout doubleValue]];
    [timer start];

    BPCreateSimulatorHandler *handler = [BPCreateSimulatorHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [BPUtils printInfo:(__handler.error ? ERROR : INFO)
                withString:@"Started: %@ %@", stepName, context.runner.UDID];
    };

    handler.onSuccess = ^{
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Successfully %@: %@", stepName, context.runner.UDID]];
        [BPUtils printInfo:(__handler.error ? ERROR : INFO)
                withString:@"Successfully %@: %@", stepName, context.runner.UDID];
        NEXT([__self installApplicationWithContext:context]);
    };

    handler.onError = ^(NSError *error) {
        [[BPStats sharedStats] addSimulatorCreateFailure];
        [BPUtils printInfo:ERROR withString:@"%@", [error localizedDescription]];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Failed %@ with error %@", stepName, [error localizedDescription]]];
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
        //when timeout, onError block will run
        [BPUtils printInfo:ERROR withString:@"Timeout: %@", stepName];
    };

    [context.runner createSimulatorWithDeviceName:deviceName completion:handler.defaultHandlerBlock];
}

- (void)reuseSimulatorWithContext:(BPExecutionContext *)context {
    NSString *stepName = REUSE_SIMULATOR(context.attemptNumber);
    
    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    [BPUtils printInfo:INFO withString:@"%@", stepName];
    NSError* useSimulatorError;
    if ([context.runner useSimulatorWithDeviceUDID:[[NSUUID alloc] initWithUUIDString:context.config.useSimUDID] withError:&useSimulatorError]) {
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Completed: %@ %@", stepName, context.runner.UDID]];
        [BPUtils printInfo:INFO withString:@"Completed: %@ %@", stepName, context.runner.UDID];
        NEXT([self uninstallApplicationWithContext:context]);
    } else {
        self.reuseSimAllowed = NO; //prevent reuse this device when RETRY
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Failed to reuse simulator because %@", [useSimulatorError localizedDescription]]];
        [[BPStats sharedStats] addSimulatorReuseFailure];
        [BPUtils printInfo:ERROR withString:@"Failed to reuse simulator"];
        context.exitStatus = BPExitStatusSimulatorCreationFailed;
        
        NEXT([self finishWithContext:context]);
    }
}

- (void)installApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = INSTALL_APPLICATION(context.attemptNumber);
    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    NSError *error = nil;
    BOOL success = [context.runner installApplicationAndReturnError:&error];

    __weak typeof(self) __self = self;
    [BPUtils printInfo:(success ? INFO : ERROR) withString:@"Completed: %@", stepName];

    if (!success) {
        [[BPStats sharedStats] addSimulatorInstallFailure];
        [BPUtils printInfo:ERROR withString:@"Could not install app in simulator: %@", [error localizedDescription]];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Could not install app in simulator: %@", [error localizedDescription]]];
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
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:@"successfully intalled Application"];
        NEXT([self launchApplicationWithContext:context]);
    }
}

- (void)uninstallApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = UNINSTALL_APPLICATION(context.attemptNumber);
    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    NSError *error = nil;
    BOOL success = [context.runner uninstallApplicationAndReturnError:&error];

    [BPUtils printInfo:(success ? INFO : ERROR) withString:@"Completed: %@", stepName];
    if (!success) {
        [[BPStats sharedStats] addSimulatorInstallFailure];
        [BPUtils printInfo:ERROR withString:@"Could not uninstall app in simulator: %@", [error localizedDescription]];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Could not uninstall app in simulator: %@", [error localizedDescription]]];
        NEXT([self deleteSimulatorWithContext:context andStatus:BPExitStatusUninstallAppFailed]);
    } else {
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:@"successfully uninstalled application"];
        NEXT([self installApplicationWithContext:context]);
    }
}

- (void)launchApplicationWithContext:(BPExecutionContext *)context {
    NSString *stepName = LAUNCH_APPLICATION(context.attemptNumber);
    [BPUtils printInfo:INFO withString:@"%@", stepName];

    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    __weak typeof(self) __self = self;

    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.launchTimeout doubleValue]];
    [timer start];

    BPApplicationLaunchHandler *handler = [BPApplicationLaunchHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [BPUtils printInfo:((__handler.pid > -1) ? INFO : ERROR) withString:@"Completed: %@", stepName];
    };

    handler.onSuccess = ^{
        [[BPStats sharedStats] startTimer:TOTAL_TEST_TIME(context.attemptNumber) withAttemptNumber:context.attemptNumber];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:@"Successfully launched application"];
        context.pid = __handler.pid;
        NEXT([__self connectTestBundleAndTestDaemonWithContext:context]);
    };

    handler.onError = ^(NSError *error) {
        [BPUtils printInfo:ERROR withString:@"Could not launch app and tests: %@", [error localizedDescription]];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[error localizedDescription]];
        [[BPStats sharedStats] addSimulatorLaunchFailure];
        if (--__self.maxLaunchTries > 0) {
            [BPUtils printInfo:INFO withString:@"Relaunching the simulator due to a BAD STATE"];
            context.runner = [__self createSimulatorRunnerWithContext:context];
            NEXT([__self createSimulatorWithContext:context]);
        } else {
            NEXT([__self deleteSimulatorWithContext:context andStatus:BPExitStatusLaunchAppFailed]);
        }
    };

    handler.onTimeout = ^{
        //TODO: Need to test this code path
        [BPUtils printInfo:ERROR withString:@"Timeout launching app"];
    };

    [context.runner launchApplicationAndExecuteTestsWithParser:context.parser forAttempt:context.attemptNumber andCompletion:handler.defaultHandlerBlock];
}

- (void)connectTestBundleAndTestDaemonWithContext:(BPExecutionContext *)context {
    if (context.isTestRunnerContext) {
        // If the isTestRunnerContext is flipped on, don't connect testbundle again.
        return;
    }
    BPTestBundleConnection *bConnection = [[BPTestBundleConnection alloc] initWithDevice:context.runner andInterface:self andConfig:self.config];
    bConnection.simulator = context.runner;
    BPTestDaemonConnection *dConnection = [[BPTestDaemonConnection alloc] initWithDevice:context.runner andInterface:nil];
    [bConnection connectWithTimeout:30];

    dConnection.testRunnerPid = context.pid;
    [dConnection connectWithTimeout:30];
    [bConnection startTestPlan];
    NEXT([self checkProcessWithContext:context]);

}
- (void)checkProcessWithContext:(BPExecutionContext *)context {

    BOOL isRunning = [self isProcessRunningWithContext:context];
    
    if (!isRunning && [context.runner isFinished]) {
        [[BPStats sharedStats] endTimer:TOTAL_TEST_TIME(context.attemptNumber) withErrorMessage:@"no error detected"];
        [self runnerCompletedWithContext:context];
        return;
    }

    if (![context.runner isSimulatorRunning]) {
        [[BPStats sharedStats] endTimer:TOTAL_TEST_TIME(context.attemptNumber) withErrorMessage:@"SIMULATOR CRASHED!!!"];
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
        [[BPStats sharedStats] endTimer:TOTAL_TEST_TIME(context.attemptNumber) withErrorMessage:@"Application crashed!"];
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
    NSInteger maxRetries = [context.config.errorRetriesCount integerValue];

    [context.parser completed];
    if ((context.attemptNumber > maxRetries) || ![self hasRemainingTestsInContext:context]) {
        // This is the final retry, so we should force a calculation if we error'd
        [context.parser completedFinalRun];
    }

    if (context.simulatorCrashed == NO) {
        // Dump standard log to stdout
        BPWriter *standardLog;
        if (context.config.plainOutput) {
            if (context.config.outputDirectory) {
                NSString *fileName = [NSString stringWithFormat:@"%lu-%@-results.txt",
                                      context.attemptNumber,
                                      [[context.config.testBundlePath lastPathComponent] stringByDeletingPathExtension]];
                NSString *outputFile = [context.config.outputDirectory stringByAppendingPathComponent:fileName];
                standardLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
            } else {
                standardLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationStdout];
            }
            [standardLog writeLine:@"%@", [context.parser generateLog:[[StandardReporter alloc] init]]];
        }

        if (context.config.junitOutput) {
            BPWriter *junitLog;
            if (context.config.outputDirectory) {
                // Only single xml entry.
                NSString *fileName = [NSString stringWithFormat:@"TEST-%@-results.xml",
                                      [[context.config.testBundlePath lastPathComponent] stringByDeletingPathExtension]];
                NSString *outputFile = [context.config.outputDirectory stringByAppendingPathComponent:fileName];
                junitLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
            } else {
                junitLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationStdout];
            }
            [junitLog removeFile];
            [junitLog writeLine:@"%@", [context.parser generateLog:[[JUnitReporter alloc] init]]];
        }

        if (context.config.jsonOutput) {
            BPWriter *jsonLog;
            if (context.config.outputDirectory) {
                NSString *fileName = [NSString stringWithFormat:@"%lu-%@-timings.json",
                                      context.attemptNumber,
                                      [[context.config.testBundlePath lastPathComponent] stringByDeletingPathExtension]];
                NSString *outputFile = [context.config.outputDirectory stringByAppendingPathComponent:fileName];
                jsonLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationFile andPath:outputFile];
            } else {
                jsonLog = [[BPWriter alloc] initWithDestination:BPWriterDestinationStdout];
            }
            [jsonLog writeLine:@"%@", [context.parser generateLog:[[JSONReporter alloc] init]]];
        }
    }

    if (context.simulatorCrashed) {
        // If we crashed, we need to retry
        [self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorCrashed];
    } else if (self.config.keepSimulator
               && (context.runner.exitStatus == BPExitStatusTestsAllPassed
                || context.runner.exitStatus == BPExitStatusTestsFailed)) {
      context.exitStatus = [context.runner exitStatus];
      NEXT([self finishWithContext:context]);
    } else {
      // If the tests failed, save as much debugging info as we can. XXX: Put this behind a flag
      if (context.runner.exitStatus != BPExitStatusTestsAllPassed && _config.saveDiagnosticsOnError) {
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
    NSString *stepName = DELETE_SIMULATOR(context.attemptNumber);

    self.reuseSimAllowed = NO; //prevent reuse this device when RETRY

    [[BPStats sharedStats] startTimer:stepName withAttemptNumber:context.attemptNumber];
    [BPUtils printInfo:INFO withString:@"%@", stepName];
    
    BPWaitTimer *timer = [BPWaitTimer timerWithInterval:[self.config.deleteTimeout doubleValue]];
    [timer start];

    BPDeleteSimulatorHandler *handler = [BPDeleteSimulatorHandler handlerWithTimer:timer];
    __weak typeof(handler) __handler = handler;

    handler.beginWith = ^{
        [BPUtils printInfo:(__handler.error ? ERROR : INFO) withString:@"Started: %@ %@", stepName, context.runner.UDID];
    };

    handler.onSuccess = ^{
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Deleted simulator due to %@. Simulator is deleted successfully", [BPExitStatusHelper stringFromExitStatus: context.exitStatus]]];
        completion();
    };

    handler.onError = ^(NSError *error) {
        [[BPStats sharedStats] addSimulatorDeleteFailure];
        [[BPStats sharedStats] endTimer:stepName withErrorMessage:[NSString stringWithFormat:@"Tried to delete simulator due to %@. Error occurred when deleting simulator %@", [BPExitStatusHelper stringFromExitStatus: context.exitStatus], [error localizedDescription]]];
        [BPUtils printInfo:ERROR withString:@"%@", [error localizedDescription]];
        completion();
    };

    handler.onTimeout = ^{
        [BPUtils printInfo:ERROR
                withString:@"Timeout: %@", stepName];
        completion();
    };

    [context.runner deleteSimulatorWithCompletion:handler.defaultHandlerBlock];
}

// Only called when bp is running in the delete only mode.
- (void)deleteSimulatorOnlyTaskWithContext:(BPExecutionContext *)context {
    
    if ([context.runner useSimulatorWithDeviceUDID:[[NSUUID alloc] initWithUUIDString:context.config.deleteSimUDID] withError:nil]) {
        NEXT([self deleteSimulatorWithContext:context andStatus:BPExitStatusSimulatorDeleted]);
    } else {
        [BPUtils printInfo:ERROR withString:@"Failed to reconnect to simulator %@", context.config.deleteSimUDID];
        context.exitStatus = BPExitStatusSimulatorReuseFailed;
        
        NEXT([self finishWithContext:context]);
    }
}

- (BOOL)hasRemainingTestsInContext:(BPExecutionContext *)context {
    // Make sure we're not doing unnecessary work on the next run.
    NSMutableSet *testsRemaining = [[NSMutableSet alloc] initWithArray:context.config.allTestCases];
    NSSet *testsToSkip = [[NSSet alloc] initWithArray:context.config.testCasesToSkip];
    [testsRemaining minusSet:testsToSkip];
    return ([testsRemaining count] > 0);
}

/**
 Scenarios:
 1. crash/time out and proceed passes -> Crash/Timeout
 2. crash/time out and retry passes -> AllPass
 3. failure and retry passes -> AllPass
 4. happy all pass -> AllPassed
 5. failure and still fails -> TestFailed
 */
- (void)finishWithContext:(BPExecutionContext *)context {

    // Because BPExitStatusTestsAllPassed is 0, we must check it explicitly against
    // the run rather than the aggregate bitmask built with finalExitStatus

    if (![self hasRemainingTestsInContext:context] && (context.attemptNumber <= [context.config.errorRetriesCount integerValue])) {
        self.finalExitStatus = context.exitStatus;
        self.exitLoop = YES;
        return;
    }

    switch (context.exitStatus) {
        // BP exit handler
        case BPExitStatusInterrupted:
            self.exitLoop = YES;
            return;

        // MARK: Test suite completed

        // If there is no test crash/time out, we retry from scratch
        case BPExitStatusTestsFailed:
            NEXT([self retry]);
            return;

        case BPExitStatusTestsAllPassed:
            // Check previous result
            if (context.finalExitStatus != BPExitStatusTestsAllPassed) {
                // If there is a test crashed/timed out before, retry from scratch
                NEXT([self retry]);
            } else {
                // If it is a real all pass, exit
                self.exitLoop = YES;
                return;
            }
            return;
        // Recover from scratch if there is tooling failure.
        case BPExitStatusSimulatorCreationFailed:
        case BPExitStatusSimulatorCrashed:
        case BPExitStatusInstallAppFailed:
        case BPExitStatusUninstallAppFailed:
        case BPExitStatusLaunchAppFailed:
        case BPExitStatusAppHangsBeforeTestStart:
        // context.exitStatus is not passed to finalExitStatus, because if recover succeeds, we should still consider exit with test all pass if no other failure happens
            NEXT([self recover]);
            return;

        // If it is test hanging or crashing, we set final exit code of current context and proceed.
        case BPExitStatusTestTimeout:
            context.finalExitStatus = BPExitStatusTestTimeout;
            NEXT([self proceed]);
            return;
        case BPExitStatusAppCrashed:
            context.finalExitStatus = BPExitStatusAppCrashed;
            NEXT([self proceed]);
            return;
        case BPExitStatusSimulatorDeleted:
        case BPExitStatusSimulatorReuseFailed:
            self.finalExitStatus = context.exitStatus;
            self.exitLoop = YES;
            return;
    }

}

- (void)writeSimUDIDFile {
    NSString *idStr = self.context.runner.UDID;
    if (!idStr) return;
    
    NSString *tempFileName = [NSString stringWithFormat:@"bluepill-deviceid.%d", getpid()];
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:tempFileName];
    
    NSError *error;
    BOOL success = [idStr writeToFile:tempFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!success) {
        [BPUtils printInfo:ERROR withString:@"ERROR: Failed to write the device ID file %@ with error: %@", tempFilePath, [error localizedDescription]];
    }
}

// MARK: Helpers

- (BOOL)continueRunning {
    return (self.exitLoop == NO);
}

- (NSString *)test_simulatorUDID {
    return self.context.runner.UDID;
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
