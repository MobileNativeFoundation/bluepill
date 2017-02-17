//
//  BPSimulator.m
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/16/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "BPSimulator.h"
#import "SimulatorHelper.h"
#import "SimulatorMonitor.h"
#import "BPConfiguration.h"
#import "BPConstants.h"
#import "CoreSimulator.h"
#import "BPTreeParser.h"
#import "BPUtils.h"
#import <AppKit/AppKit.h>
#import <sys/stat.h>
#import "BPTestBundleConnection.h"
#import "BPTestDaemonConnection.h"

@interface BPSimulator()

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) NSRunningApplication *app;
@property (nonatomic, strong) NSFileHandle *stdOutHandle;
@property (nonatomic, strong) SimulatorMonitor *monitor;
@property (nonatomic, assign) BOOL needsRetry;

@end

@implementation BPSimulator

+ (instancetype)simulatorWithConfiguration:(BPConfiguration *)config {
    BPSimulator *sim = [[self alloc] init];
    sim.config = config;
    return sim;
}

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion {
    assert(!self.device);
    deviceName = deviceName ?: [NSString stringWithFormat:@"BP%d", getpid()];
    // Create a new simulator with the given device/runtime
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    if (!sc) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"SimServiceContext failed: %@", [error localizedDescription]]];
        return;
    }
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (!deviceSet) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"SimDeviceSet failed: %@", [error localizedDescription]]];
        return;
    }

    __weak typeof(self) __self = self;
    [deviceSet createDeviceAsyncWithType:self.config.simDeviceType
                                 runtime:self.config.simRuntime
                                    name:deviceName
                       completionHandler:^(NSError *error, SimDevice *device) {
                           __self.device = device;
                           if (!__self.device || error) {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   completion(error);
                               });
                           } else {
                               dispatch_async(dispatch_get_main_queue(), ^{
                                   [__self bootWithCompletion:^(NSError *error) {
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           completion(error);
                                       });
                                   }];
                               });
                           }
                       }];
}

- (void)bootWithCompletion:(void (^)(NSError *error))completion {
    // Now boot it.
    if (self.config.headlessMode) {
        NSDictionary *options = @{
                                  @"register-head-services" : @YES
                                  };
        [self.device bootAsyncWithOptions:options completionHandler:completion];
        return;
    }
    // not headless? open the simulator app.
    [self openSimulatorWithCompletion:completion];
}

- (void)openSimulatorWithCompletion:(void (^)(NSError *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSError *error;
        NSURL *simulatorURL = [NSURL fileURLWithPath:
                               [NSString stringWithFormat:@"%@/Applications/Simulator.app/Contents/MacOS/Simulator",
                                self.config.xcodePath]];

        NSDictionary *configuration = @{NSWorkspaceLaunchConfigurationArguments: @[@"-CurrentDeviceUDID", [[self.device UDID] UUIDString]]};
        NSWorkspaceLaunchOptions launchOptions = NSWorkspaceLaunchAsync |
        NSWorkspaceLaunchWithoutActivation |
        NSWorkspaceLaunchAndHide |
        NSWorkspaceLaunchNewInstance;
        self.app = [[NSWorkspace sharedWorkspace]
                    launchApplicationAtURL:simulatorURL
                    options:launchOptions
                    configuration:configuration
                    error:&error];
        if (!self.app) {
            assert(error != nil);
            completion(error);
        }
        int attempts = 100;
        while (attempts > 0 && ![self.device.stateString isEqualToString:@"Booted"]) {
            [NSThread sleepForTimeInterval:0.1];
            --attempts;
        }
        if (![self.device.stateString isEqualToString:@"Booted"]) {
            [self.app terminate];
            error = [NSError errorWithDomain:@"Simulator failed to boot" code:-1 userInfo:nil];
            completion(error);
            return;
        }

        completion(nil);
        return;
    });
}

- (BOOL)installApplicationAndReturnError:(NSError *__autoreleasing *)error {

    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:self.config.appBundlePath];
    NSString *hostBundlePath = self.config.appBundlePath;

    hostBundleId = @"com.apple.test.BPSampleAppUITests-Runner";
    hostBundlePath = @"/Users/khu/linkedin/bluepill/build/Products/Debug-iphonesimulator/BPSampleAppUITests-Runner.app";
    // Install the host application
    BOOL installed = [self.device
                      installApplication:[NSURL fileURLWithPath:hostBundlePath]
                      withOptions:@{kCFBundleIdentifier: hostBundleId}
                      error:error];
    if (!installed) {
        return NO;
    }
    return YES;
}

- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser andCompletion:(void (^)(NSError *, pid_t))completion {

    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:self.config.appBundlePath];
    NSString *hostAppExecPath = [SimulatorHelper executablePathforPath:self.config.appBundlePath];

    if (self.config.testRunnerPath) {
        hostAppExecPath = self.config.testRunnerPath;
        hostBundleId = @"com.apple.test.BPSampleAppUITests-Runner";
    }
    // Create the environment for the host application
    NSDictionary *argsAndEnv = [BPUtils buildArgsAndEnvironmentWith:self.config.schemePath];

    NSMutableDictionary *appLaunchEnvironment = [NSMutableDictionary dictionaryWithDictionary:[SimulatorHelper appLaunchEnvironmentWithBundleID:hostBundleId device:self.device config:self.config]];
    [appLaunchEnvironment addEntriesFromDictionary:argsAndEnv[@"env"]];

    if (self.config.testing_CrashAppOnLaunch) {
        appLaunchEnvironment[@"_BP_TEST_CRASH_ON_LAUNCH"] = @"YES";
    }
    if (self.config.testing_HangAppOnLaunch) {
        appLaunchEnvironment[@"_BP_TEST_HANG_ON_LAUNCH"] = @"YES";
    }

    // Intercept stdout, stderr and post as simulator-output events
    NSString *stdout_stderr = [NSString stringWithFormat:@"%@/tmp/stdout_stderr_%@", self.device.dataPath, [[self.device UDID] UUIDString]];
    NSString *simStdoutPath = [BPUtils mkstemp:stdout_stderr withError:nil];
    assert(simStdoutPath != nil);

    NSString *simStdoutRelativePath = [simStdoutPath substringFromIndex:((NSString *)self.device.dataPath).length];
    [[NSFileManager defaultManager] removeItemAtPath:simStdoutPath error:nil];

    mkfifo([simStdoutPath UTF8String], S_IWUSR | S_IRUSR | S_IRGRP);

    NSMutableDictionary *appLaunchEnv = [appLaunchEnvironment mutableCopy];
    [appLaunchEnv setObject:simStdoutRelativePath forKey:kOptionsStdoutKey];
    [appLaunchEnv setObject:simStdoutRelativePath forKey:kOptionsStderrKey];

    int fd = open([simStdoutPath UTF8String], O_RDWR);
    self.stdOutHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];

    appLaunchEnvironment = [appLaunchEnv copy];

    NSDictionary *options = @{
                              kOptionsArgumentsKey: argsAndEnv[@"args"],
                              kOptionsEnvironmentKey: appLaunchEnvironment,
                              kOptionsWaitForDebuggerKey: @"0",
                              kOptionsStdoutKey: simStdoutRelativePath,
                              kOptionsStderrKey: simStdoutRelativePath
                              };

    if (!self.monitor) {
        self.monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];
    }
    self.monitor.device = self.device;
    self.monitor.hostBundleId = hostBundleId;
    parser.delegate = self.monitor;

    // Keep the simulator runner around through processing of the block
    __block typeof(self) blockSelf = self;

    NSError *infoError;
    NSDictionary *appInfo = [self.device propertiesOfApplication:hostBundleId error:&infoError];
    if (infoError) {
        NSLog(@"Error in getting appInfo %@", [infoError localizedDescription]);
    }

    NSString *appPath = appInfo[@"Path"];
    self.config.testBundlePath = [NSString stringWithFormat:@"%@/Plugins/BPSampleAppUITests.xctest", appPath];

    __block pid_t pid_test = 0;
    [self.device launchApplicationAsyncWithID:hostBundleId options:options completionHandler:^(NSError *error, pid_t pid) {
        // Save the process ID to the monitor
        blockSelf.monitor.appPID = pid;
        pid_test = pid;

        if (error == nil) {
            dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, pid, DISPATCH_PROC_EXIT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
            dispatch_source_set_event_handler(source, ^{
                dispatch_source_cancel(source);
            });
            dispatch_source_set_cancel_handler(source, ^{
                // Post a APPCLOSED signal to the fifo
                [blockSelf.stdOutHandle writeData:[@"\nBP_APP_PROC_ENDED\n" dataUsingEncoding:NSUTF8StringEncoding]];
            });
            dispatch_resume(source);
            self.stdOutHandle.readabilityHandler = ^(NSFileHandle *handle) {
                NSData *chunk = [handle availableData];
                [parser handleChunkData:chunk];
            };
        }
    }];
    [BPUtils runWithTimeOut:3600 until:^BOOL{
        return pid_test != 0;
    }];
    BPTestBundleConnection *bConnection = [[BPTestBundleConnection alloc] initWithDevice:self.device andInterface:nil];
    bConnection.config = self.config;


    BPTestDaemonConnection *dConnection = [[BPTestDaemonConnection alloc] initWithDevice:self.device andInterface:nil];
    [bConnection connectWithTimeout:3600];
    
    dConnection.testRunnerPid = pid_test;
    [dConnection connectWithTimeout:3600];
    [bConnection startTestPlan];
    
}

- (void)deleteSimulatorWithCompletion:(void (^)(NSError *error, BOOL success))completion {
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (self.app) {
        [self.app terminate];
        // We need to wait until the simulator has shut down.
        int attempts = 300;
        while (attempts > 0 && ![self.device.stateString isEqualToString:@"Shutdown"]) {
            [NSThread sleepForTimeInterval:1.0];
            --attempts;
        }
        if (![self.device.stateString isEqualToString:@"Shutdown"]) {
            NSLog(@"Timed out waiting for %@ to shutdown. It won't be deleted. Last state: %@", self.device.name, self.device.stateString);
            // Go ahead and try to delete anyway
        }
        [deviceSet deleteDeviceAsync:self.device completionHandler:^(NSError *error) {
            if (error) {
                NSLog(@"Could not delete simulator: %@", [error localizedDescription]);
            }
            completion(error, error ? NO: YES);
        }];
    } else {
        [self.device shutdownAsyncWithCompletionHandler:^(NSError *error) {
            if (!error) {
                [deviceSet deleteDeviceAsync:self.device completionHandler:^(NSError *error) {
                    if (error) {
                        NSLog(@"Could not delete simulator: %@", [error localizedDescription]);
                    }
                    completion(error, error ? NO: YES);
                }];
            } else {
                NSLog(@"Could not shutdown simulator: %@", [error localizedDescription]);
                completion(error, NO);
            }
        }];
    }
}

#pragma mark - helper methods

- (BOOL)isSimulatorRunning {
    NSError *error = nil;
    BOOL isRunning = [[self.device stateString] isEqualToString:@"Booted"];
    BOOL isAvailable = [self.device isAvailableWithError:&error];
    if (error) {
        fprintf(stderr, "%s\n", [[error description] UTF8String]);
    }
    return isRunning && isAvailable;
}

- (BOOL)isFinished {
    return [self checkFinished];
}

- (BOOL)checkFinished {
    if ([self.monitor isExecutionComplete]) {
        switch ([self.monitor exitStatus]) {
            case BPExitStatusTestsAllPassed:
            case BPExitStatusTestsFailed:
                return YES;
            default:
                // We should retry. Unless we've retried too many times.
                self.needsRetry = YES;
                return YES;
        }
    }
    return NO;
}

- (BPExitStatus)exitStatus {
    return ([self.monitor exitStatus]);
}

- (NSString *)UDID {
    return [self.device.UDID UUIDString];
}

@end
