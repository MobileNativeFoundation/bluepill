//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <AppKit/AppKit.h>
#import <sys/stat.h>
#import "BPConfiguration.h"
#import "BPConstants.h"
#import "BPCreateSimulatorHandler.h"
#import "BPSimulator.h"
#import "BPTreeParser.h"
#import "BPUtils.h"
#import "BPWaitTimer.h"
#import "PrivateHeaders/CoreSimulator/CoreSimulator.h"
#import "SimulatorHelper.h"
#import <BPTestInspector/BPTestInspectorConstants.h>
#import <BPTestInspector/BPTestCaseInfo.h>

@interface BPSimulator()

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) NSRunningApplication *app;
@property (nonatomic, strong) NSFileHandle *appOutput;
@property (nonatomic, assign) BOOL needsRetry;
@property (nonatomic, strong) NSMutableArray* simDeviceTemplates;

@end

@implementation BPSimulator

+ (instancetype)simulatorWithConfiguration:(BPConfiguration *)config {
    BPSimulator *sim = [[self alloc] init];
    sim.config = config;
    return sim;
}

- (NSMutableDictionary *)createSimulatorAndInstallAppWithBundles:(NSArray<BPXCTestFile *>*)testBundles {
    NSMutableDictionary* testHostSimTemplates = [[NSMutableDictionary alloc] init];
    NSString *simulatorUDIDString = nil;
    NSError *error = nil;
    if (self.config.appBundlePath) {
        // This is for integration testing for bluepill and bluepill-cli when we assign self.config.appBundlePath
        simulatorUDIDString = [self installApplicationWithHost:self.config.appBundlePath withError:&error];
        if (!simulatorUDIDString || error) {
            [BPUtils printInfo:ERROR withString:@"Create simualtor and install application failed with error: %@", error];
            return FALSE;
        }
        testHostSimTemplates[self.config.appBundlePath] = simulatorUDIDString;
        [BPUtils printInfo:INFO withString:@"Created sim template: %@ for app host: %@", simulatorUDIDString, self.config.appBundlePath];
    } else {
        // This is for testing in command line when we pass the xctestrun file
        NSMutableSet *hostBundles = [[NSMutableSet alloc] init];
        for (BPXCTestFile* bundle in testBundles) {
            [hostBundles addObject:bundle.testHostPath];
        }
        if ([testBundles count] == 0) {
            [BPUtils printInfo:ERROR withString:@"No host bundle founnd!"];
        }
        for (NSString *appPath in hostBundles) {
            NSError *error = nil;
            simulatorUDIDString = [self installApplicationWithHost:appPath withError:&error];
            if (!simulatorUDIDString || error) {
                [BPUtils printInfo:ERROR withString:@"Created simulator template and install applicationn failed with error: %@", error];
                return FALSE;
            }
            [BPUtils printInfo:INFO withString:@"Created sim template: %@ for app host: %@", simulatorUDIDString, appPath];
            testHostSimTemplates[appPath] = simulatorUDIDString;
        }
    }
    return testHostSimTemplates;
}

- (NSString *)getErrorDescription:(NSError *__autoreleasing *)errPtr {
    return errPtr != nil ? [*errPtr localizedDescription] : nil;
}

- (NSString *)installApplicationWithHost:(NSString *)testHost withError:(NSError *__autoreleasing *)errPtr {
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:errPtr];
    if (!sc && *errPtr) {
        [BPUtils printInfo:ERROR withString:@"SimServiceContext failed: %@", [*errPtr localizedDescription]];
        return nil;
    }
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:errPtr];
    if (!deviceSet && *errPtr) {
        [BPUtils printInfo:ERROR withString:@"SimDeviceSet failed: %@", [*errPtr localizedDescription]];
        return nil;
    }
    SimDevice *simDevice = [deviceSet createDeviceWithType:self.config.simDeviceType
                                                   runtime:self.config.simRuntime
                                                      name:[NSString stringWithFormat:@"BP-Template-%u", getpid()]
                                                     error:errPtr];
    if (!self.simDeviceTemplates) {
        self.simDeviceTemplates = [[NSMutableArray alloc] init];
    }
    [self.simDeviceTemplates addObject:simDevice];
    if (!simDevice && *errPtr) {
        [BPUtils printInfo:ERROR withString:@"Create simulator failed with error: %@", [*errPtr localizedDescription]];
        return nil;
    }
    [simDevice bootWithOptions:nil error:errPtr];
    if (*errPtr) {
        [BPUtils printInfo:ERROR withString:@"Boot simulator failed with error: %@", [*errPtr localizedDescription]];
        return nil;
    }
    // Add photos and videos to the simulator.
    [self addPhotosToSimulator];
    [self addVideosToSimulator];
    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:testHost];
    if (!hostBundleId) {
        [BPUtils printInfo:ERROR withString:@"Could not find test bundle id for %@", testHost];
        return nil;
    }
    // Install the host application
    NSError *installError = nil;
    bool installed = [simDevice installApplication:[NSURL fileURLWithPath:testHost]
                                       withOptions:@{kCFBundleIdentifier: hostBundleId}
                                             error:&installError];
    if (!installed) {
        [BPUtils printInfo:ERROR withString:@"Install application failed with error: %@", [installError localizedDescription]];
        [deviceSet deleteDeviceAsync:simDevice completionHandler:^(NSError *error) {
            if (error) {
                [BPUtils printInfo:ERROR withString:@"Could not delete simulator: %@", [error localizedDescription]];
            }
        }];
        return nil;
    } else {
        [simDevice shutdownWithError:errPtr];
        if(*errPtr) {
            [BPUtils printInfo:ERROR withString:@"Shutdown simulator failed with error: %@", [*errPtr localizedDescription]];
            [deviceSet deleteDeviceAsync:simDevice completionHandler:^(NSError *error) {
                if (error) {
                    [BPUtils printInfo:ERROR withString:@"Could not delete simulator: %@", [error localizedDescription]];
                }
            }];
            return nil;
        }
    }
    return simDevice.UDID.UUIDString;
}

- (void)deleteTemplateSimulator {
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    for(SimDevice *simDevice in self.simDeviceTemplates) {
        [deviceSet deleteDeviceAsync:simDevice completionHandler:^(NSError *error) {
            if (error) {
                [BPUtils printInfo:ERROR withString:@"Could not delete simulator: %@", [error localizedDescription]];
            }
        }];
    }
}

- (void)createSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion {
    assert(!self.device);
    deviceName = deviceName ?: [NSString stringWithFormat:@"BP%d", getpid()];
    // Create a new simulator with the given device/runtime
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    if (!sc) {
        [BPUtils printInfo:ERROR withString:@"SimServiceContext failed: %@", [error localizedDescription]];
        return;
    }
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (!deviceSet) {
        [BPUtils printInfo:ERROR withString:@"SimDeviceSet failed: %@", [error localizedDescription]];
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
                               if (__self.config.simulatorPreferencesFile) {
                                   [__self copySimulatorPreferencesFile:__self.config.simulatorPreferencesFile];
                               }

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

- (void)cloneSimulatorWithDeviceName:(NSString *)deviceName completion:(void (^)(NSError *))completion {
    assert(!self.device);
    deviceName = deviceName ?: [NSString stringWithFormat:@"BP%d", getpid()];
    // Create a new simulator with the given device/runtime
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    if (!sc) {
        [BPUtils printInfo:ERROR withString:@"SimServiceContext failed: %@", [error localizedDescription]];
        return;
    }
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (!deviceSet) {
        [BPUtils printInfo:ERROR withString:@"SimDeviceSet failed: %@", [error localizedDescription]];
        return;
    }
    SimDevice *simulatorWithAppInstalled = [self findDeviceWithConfig:self.config andDeviceID:[[NSUUID alloc] initWithUUIDString:self.config.templateSimUDID]];
    [BPUtils printInfo:INFO withString:@"Clone with simulator template: %@", self.config.templateSimUDID];
    __weak typeof(self) __self = self;
    [deviceSet cloneDeviceAsync:simulatorWithAppInstalled name:deviceName completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) completionHandler:^(NSError *error, SimDevice *device){
        __self.device = device;
        if (!__self.device || error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error);
            });
        } else {
            if (__self.config.simulatorPreferencesFile) {
                [__self copySimulatorPreferencesFile:__self.config.simulatorPreferencesFile];
            }

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


- (NSURL *)preferencesFile {
    return [NSURL fileURLWithPath:kSimulatorLibraryPath relativeToURL:[NSURL fileURLWithPath:self.device.dataPath]];
}

- (void)copySimulatorPreferencesFile:(NSString *)newPreferencesFile {

    NSURL *source = [NSURL fileURLWithPath:newPreferencesFile];
    NSURL *destination = self.preferencesFile;


    [NSFileManager.defaultManager
            createDirectoryAtURL:destination.URLByDeletingLastPathComponent
     withIntermediateDirectories:YES
                      attributes:nil
                           error:nil];

    [NSFileManager.defaultManager removeItemAtURL:destination error:nil];

    NSError *copyError = nil;
    [NSFileManager.defaultManager copyItemAtURL:source toURL:destination error:&copyError];

    if (copyError) {
        [BPUtils printInfo:ERROR withString:@"%@", [NSString stringWithFormat:@"Failed copying GlobalPreferences plist: %@", [copyError localizedDescription]]];
    }
}

- (void)runScriptFile:(NSString *)scriptFilePath {
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:scriptFilePath];
    NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
    [env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
    [env setObject:[NSString stringWithFormat:@"%@", self.device.UDID.UUIDString] forKey:@"BP_DEVICE_ID"];
    [env setObject:[NSString stringWithFormat:@"%@", self.device.devicePath] forKey:@"BP_DEVICE_PATH"];
    [task setEnvironment:env];

    [task launch];
    [task waitUntilExit];
    int status = [task terminationStatus];
    [BPUtils printInfo:INFO withString:@"Script (%@) has finished with exit code %d.",
         scriptFilePath, [task terminationStatus]];

    if (status != 0) {
        [BPUtils printInfo:ERROR withString:@"Failed running script: %@", scriptFilePath];
    }
}

- (BOOL)useSimulatorWithDeviceUDID:(NSUUID *)deviceUDID {
    self.device = [self findDeviceWithConfig:self.config andDeviceID:deviceUDID];
    if (!self.device) {
        [BPUtils printInfo:ERROR withString:@"SimDevice not found: %@", [deviceUDID UUIDString]];
        return NO;
    }

    if (![self.device.stateString isEqualToString:@"Booted"]) {
        [BPUtils printInfo:ERROR withString:@"SimDevice exists, but not booted: %@", [deviceUDID UUIDString]];
        return NO;
    }

    if (!self.config.headlessMode) {
        self.app = [self findSimGUIApp];
        if (!self.app) {
            [BPUtils printInfo:ERROR withString:@"SimDevice running, but no running Simulator App in non-headless mode: %@",
                                                 [deviceUDID UUIDString]];
            return NO;
        }
    }

    return YES;
}

- (void)bootWithCompletion:(void (^)(NSError *error))completion {
    // Now boot it.
    [BPUtils printInfo:INFO withString:@"Booting a simulator without launching Simulator app"];
    [self openSimulatorHeadlessWithCompletion:completion];
}

- (void)openSimulatorHeadlessWithCompletion:(void (^)(NSError *))completion {
    NSDictionary *options = @{
                              @"register-head-services" : @YES
                              };
    [self.device bootAsyncWithOptions:options completionHandler:^(NSError *bootError){
        NSError *error = [self waitForDeviceReady];
        if (error) {
            [self.device shutdownWithError:&error];
            if (error) {
                [BPUtils printInfo:ERROR withString:@"Shutting down Simulator failed: %@", [error localizedDescription]];
            }
        }
        completion(bootError);
    }];
}

- (NSError *)waitForDeviceReady {
    int attempts = 1200;
    while (attempts > 0 && ![self.device.stateString isEqualToString:@"Booted"]) {
        [NSThread sleepForTimeInterval:0.1];
        --attempts;
    }
    if (![self.device.stateString isEqualToString:@"Booted"]) {
        [BPUtils printInfo:ERROR withString:@"Simulator %@ failed to boot. State: %@", self.device.UDID.UUIDString, self.device.stateString];
        return [NSError errorWithDomain:@"Simulator failed to boot" code:-1 userInfo:nil];
    }
    [BPUtils printInfo:INFO withString:@"Simulator %@ achieved the BOOTED state %@", self.device.UDID.UUIDString, self.device.stateString];
    return nil;
}

- (SimDevice *)findDeviceWithConfig:(BPConfiguration *)config andDeviceID:(NSUUID *)deviceID {
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:config.xcodePath error:&error];
    if (!sc) {
        [BPUtils printInfo:ERROR withString:@"SimServiceContext failed: %@", [error localizedDescription]];
        return nil;
    }
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (!deviceSet) {
        [BPUtils printInfo:ERROR withString:@"SimDeviceSet failed: %@", [error localizedDescription]];
        return nil;
    }

    SimDevice *device = deviceSet.devicesByUDID[deviceID];
    return device; //could be nil when not found
 }

- (NSRunningApplication *)findSimGUIApp {
    NSString *cmd = [NSString stringWithFormat:@"ps -A | grep 'Simulator\\.app'"];
    NSString *output = [[BPUtils runShell:cmd] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSArray *fields = [output componentsSeparatedByString: @" "];
    if ([fields count] > 0) {
        NSString *pidStr = [fields objectAtIndex:0];
        int pid = [pidStr intValue];
        NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        return app;
    }
    return nil;
}

- (void)addVideosToSimulator {
    for (NSString *urlString in self.config.videoPaths) {
        NSURL *videoUrl = [NSURL fileURLWithPath:urlString];
        NSError *error;
        BOOL uploadResult = [self.device addVideo:videoUrl error:&error];
        if (!uploadResult && error) {
            [BPUtils printInfo:ERROR withString:@"Failed to upload video at path: %@, error message: %@", urlString, [error description]];
        }
    }
}

- (void)addPhotosToSimulator {
    for (NSString *urlString in self.config.imagePaths) {
        NSURL *photoUrl = [NSURL fileURLWithPath:urlString];
        NSError *error;
        BOOL uploadResult = [self.device addPhoto:photoUrl error:&error];
        if (!uploadResult && error) {
            [BPUtils printInfo:ERROR withString:@"Failed to upload photo at path: %@, error message: %@", urlString, [error description]];
        }
    }
}

- (BOOL)installApplicationWithError:(NSError *__autoreleasing *)errPtr {
    // Add photos and videos to the simulator.
    [self addPhotosToSimulator];
    [self addVideosToSimulator];

    // Install the app
    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:self.config.appBundlePath];
    NSString *hostBundlePath = self.config.appBundlePath;

    if (self.config.testRunnerAppPath) {
        NSString *hostAppPath = self.config.testRunnerAppPath;
        hostBundleId = [SimulatorHelper bundleIdForPath:hostAppPath];
        hostBundlePath = hostAppPath;
    }
    if (!hostBundleId || !hostBundlePath) {
        [BPUtils printInfo:ERROR withString:@"hostBundleId: %@ or hostBundlePath: %@ is null",
         hostBundleId, hostBundlePath];
        return NO;
    }
    [BPUtils printInfo:DEBUGINFO withString: @"installApplication: host bundleId: %@, host BundlePath: %@, testRunnerAppPath: %@", hostBundleId, hostBundlePath, self.config.testRunnerAppPath];
    // Install the host application
    BOOL installed = [self.device
                      installApplication:[NSURL fileURLWithPath:hostBundlePath]
                      withOptions:@{kCFBundleIdentifier: hostBundleId}
                      error:errPtr];
    if (!installed) {
        return NO;
    }
    return YES;
}

- (BOOL)uninstallApplicationWithError:(NSError *__autoreleasing *)errPtr {
    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:self.config.appBundlePath];

    // Install the host application
    return [self.device uninstallApplication:hostBundleId
                                 withOptions:@{kCFBundleIdentifier: hostBundleId}
                                       error:errPtr];
}

/**
 Logic tests are run directly on the simulator by spawning a new process with the XCTest executable, without any kind of host app.
 */
- (void)executeLogicTestsWithParser:(BPTreeParser *)parser
                            onSpawn:(void (^)(NSError *, pid_t))spawnBlock
                      andCompletion:(void (^)(NSError *, pid_t))completionBlock {
    /*
     Grab all test cases so that we can:
       1) create a timeout for the full test execution
       2) Support opting-out of tests, despite the fact that XCTest only provides an opt-in API.
     */
    NSArray<NSString *> *testsToRun = [SimulatorHelper testsToRunWithConfig:self.config];
    NSString *testsToRunArg = testsToRun.count == self.config.allTestCases.count ? @"All" : [testsToRun componentsJoinedByString:@","];

    /*
     It can be useful to understand how to translate the public Breaking down CLI command `xcrun simctl spawn... <path>`, which you'd
     use to run a logic test from commandline, into the form that Bluepill must use, which is CoreSimulator's private `spawnWithPath`:
     
     When trying to run a command such as
        ```
        xcrun simctl spawn -s AFF4165A-9A71-4860-8B6D-485B7D1BA2BC
            /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/Library/Xcode/Agents/xctest
            -XCTest BPLogicTests/testPassingLogicTest /Users/.../BPLogicTests.xctest
        ```
     we can break down the individual components to be handled in the following:
     - part of the method signature:
        - xcrun simctl                          // these just redirect down to CoreSimulator
        - spawn                                 // this is the the spawn method :p
        - AFF4165A-9A71-4860-8B6D-485B7D1BA2BC  // We're calling device.spawn. No need to respecify the device ID
     - path: /Applications/.../Xcode/Agents/xctest
     - options:
        - -s                                    // "standalone" option
        - -w                                    // "wait_for_debugger" option
     - args:
        - /Applications/.../Xcode/Agents/xctest                         // Yes, spawn redundantly requires this both the path param + an arg :)
        - -XCTest
        - BPLogicTests/testPassingLogicTest                             // The filter for which tests to actually run. `All` is the catch-all.
        - /Users/.../BPLogicTests.xctest                                // The path to the .xctest file w/ all the module's tests.
     
     From `xcrun simctl spawn help`:
     `simctl spawn [-w | --wait-for-debugger] [-s | --standalone] [-a <arch> | --arch=<arch>] <device> <path to executable> [<argv 1> <argv 2> ... <argv n>]`
     */
    NSString *xctestPath = self.config.testBundlePath;
    NSArray *arguments = @[
        self.config.xctestBinaryPath,
        @"-XCTest",
        testsToRunArg,
        xctestPath,
    ];

    // Intercept stdout, stderr and post as simulator-output events
    NSString *simStdoutPath = [SimulatorHelper makeStdoutFileOnDevice:self.device];
    NSString *simStdoutRelativePath = [simStdoutPath substringFromIndex:self.device.dataPath.length];
    // Environment
    NSMutableDictionary *environment = [@{
        kOptionsStdoutKey: simStdoutRelativePath,
        kOptionsStderrKey: simStdoutRelativePath,
    } mutableCopy];
    if (self.config.dyldFrameworkPath) {
        environment[@"DYLD_FRAMEWORK_PATH"] = self.config.dyldFrameworkPath;
        environment[@"DYLD_LIBRARY_PATH"] = self.config.dyldFrameworkPath;
        [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] set DYLD_FRAMEWORK_PATH = %@", environment[@"DYLD_FRAMEWORK_PATH"]];

    }
    [environment addEntriesFromDictionary:self.config.environmentVariables];
    
    self.appOutput = [NSFileHandle fileHandleForReadingAtPath:simStdoutPath];
    
    NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:simStdoutPath];
    NSNumber *stdoutFileDescriptor = @(outputFileHandle.fileDescriptor);

    NSDictionary *options = @{
        kOptionsArgumentsKey: arguments,
        kOptionsEnvironmentKey: environment,
        @"standalone": @(1),
        @"stdout": stdoutFileDescriptor,
        @"stderr": stdoutFileDescriptor,
    };

    // Set up monitor
    if (!self.monitor) {
        self.monitor = [[SimulatorMonitor alloc] initWithConfiguration:self.config];
    }
    self.monitor.device = self.device;
    parser.delegate = self.monitor;

    self.appOutput.readabilityHandler = ^(NSFileHandle *handle) {
        // This callback occurs on a background thread
        NSData *chunk = [handle availableData];
        [parser handleChunkData:chunk];
    };
    
    
    [BPUtils printInfo:INFO withString:@"[LTHROCKM DEBUG] options = %@", options];

    // To see more on how to debug the expected format/inputs of the options array,
    // see the in-depth documentation in SimDevice.h.
    __block typeof(self) blockSelf = self;
    [self.device spawnAsyncWithPath:self.config.xctestBinaryPath
                            options:options
                 terminationHandler:^(int stat_loc) {
        // The naming here is confusing, but this `terminationHandler` is called once
        // the xctest process COMPLETES. The `completionHandler` below is used earlier,
        // once the xctest process is SPAWNED.
        
        // Check the location where the status code is stored;
        // Handle error if there is a signal or non-zero exit code.
        NSError *error = [BPSimulator errorFromStatusLocation:stat_loc];
        if (error) {
            [blockSelf signalCloseToParser:parser fileHandle:outputFileHandle];
        }
        [blockSelf cleanUpParser:parser];
        completionBlock(error, blockSelf.monitor.appPID);
    } completionHandler:^(NSError *error, pid_t pid) {
        // Again, this `completionHandler` is called once the process is done SPAWNING,
        // as opposed to happening after the process itself has finished.
        blockSelf.monitor.appPID = pid;
        blockSelf.monitor.appState = Running;
        spawnBlock(error, pid);
    }];
}

- (void)collectTestSuiteInfoWithCompletion:(void (^)(NSArray<BPTestCaseInfo *> *, NSError *))completionBlock {
    NSString *xctestPath = self.config.testBundlePath;
    NSArray *arguments = @[
        self.config.xctestBinaryPath,
        @"-XCTest",
        @"All",
        xctestPath,
    ];

    NSString *testSuiteInfoOutputPath = [SimulatorHelper makeTestWrapperOutputFileOnDevice:self.device];
    // Intercept stdout, stderr and post as simulator-output events
    NSString *simStdoutPath = [SimulatorHelper makeStdoutFileOnDevice:self.device];
    NSString *simStdoutRelativePath = [simStdoutPath substringFromIndex:self.device.dataPath.length];

    // Environment
    NSMutableDictionary *environment = [[SimulatorHelper logicTestEnvironmentWithConfig:self.config stdoutRelativePath:simStdoutRelativePath] mutableCopy];
    
    environment[@"DYLD_INSERT_LIBRARIES"] = [BPUtils findBPTestInspectorDYLIB];
    environment[BPTestInspectorConstants.outputPathEnvironmentKey] = testSuiteInfoOutputPath;
    environment[BPTestInspectorConstants.testBundleEnvironmentKey] = xctestPath;
    
    NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:simStdoutPath];
    NSNumber *stdoutFileDescriptor = @(outputFileHandle.fileDescriptor);

    NSDictionary *options = @{
        kOptionsArgumentsKey: arguments,
        kOptionsEnvironmentKey: environment,
        @"standalone": @(1),
//        @"stdout": @(1),
//        @"stderr": @(2),
//        @"stdout": stdoutFileDescriptor,
//        @"stderr": stdoutFileDescriptor,
    };

    NSLog(@"[LTHROCKM DEBUG] simStdoutPath: %@", simStdoutPath);

    // To see more on how to debug the expected format/inputs of the options array,
    // see the in-depth documentation in SimDevice.h.
    __block typeof(self) blockSelf = self;
    [self.device spawnAsyncWithPath:self.config.xctestBinaryPath
                            options:options
                 terminationHandler:^(int stat_loc) {
        NSError *error = [BPSimulator errorFromStatusLocation:stat_loc];
        if (error) {
            completionBlock(nil, error);
            return;
        }
        // Retrieve test data
        NSError *unarchiveError;
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:testSuiteInfoOutputPath];
        NSData *testData = [fileHandle readDataToEndOfFile];
        NSArray<BPTestCaseInfo *> *testBundleInfo = [NSKeyedUnarchiver unarchivedArrayOfObjectsOfClass:BPTestCaseInfo.class
                                                                                              fromData:testData
                                                                                                 error:&unarchiveError];
        [fileHandle closeFile];
        // Cleanup + Completion
        [NSFileManager.defaultManager removeItemAtPath:testSuiteInfoOutputPath error:nil];
        completionBlock(testBundleInfo, unarchiveError);
    } completionHandler:^(NSError *error, pid_t pid) {
        if (error) {
            completionBlock(nil, error);
        }
    }];
}

+ (NSError *)errorFromStatusLocation:(int)stat_loc {
    NSError *error;
    if (WIFSIGNALED(stat_loc)) {
        int signalCode = WTERMSIG(stat_loc);
        // Ignore if the process was killed -- this occurs when we're killing
        // a timed-out test, and shouldn't be treated as a crash.
        if (signalCode != SIGKILL) {
            [BPUtils printInfo:DEBUGINFO withString: @"Spawned XCTest execution failed with signal code: %@", @(signalCode)];
            return [BPUtils errorWithSignalCode:signalCode];
        }
    } else {
        // A non-zero exit code could mean a failed test or something more serious, but we can't tell the difference here.
        // The best we can do is log the error code as debug info.
        int exitCode = WEXITSTATUS(stat_loc);
        if (exitCode) {
            [BPUtils printInfo:DEBUGINFO withString: @"Spawned XCTest execution failed with error code: %@", @(exitCode)];
        }
    }
    return nil;
}

// Posts a APPCLOSED signal to the parser, indicating a crash/kill
- (void)signalCloseToParser:(BPTreeParser *)parser fileHandle:(NSFileHandle *)fileHandle {
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[@"\nBP_APP_PROC_ENDED\n" dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (void)cleanUpParser:(BPTreeParser *)parser {
    self.monitor.appState = Completed;
    [parser.delegate setParserStateCompleted];
}

+ (NSMutableArray<NSString *> *)commandLineArgsFromConfig:(BPConfiguration *)config {
    NSArray *argumentsArr = config.commandLineArguments ?: @[];
    NSMutableArray *commandLineArgs = [NSMutableArray array];
    for (NSString *argument in argumentsArr) {
        NSArray *argumentsArray = [argument componentsSeparatedByString:@" "];
        for (NSString *arg in argumentsArray) {
            if (![arg isEqualToString:@""]) {
                [commandLineArgs addObject:arg];
            }
        }
    }
    return commandLineArgs;
}

- (void)launchApplicationAndExecuteTestsWithParser:(BPTreeParser *)parser andCompletion:(void (^)(NSError *, pid_t))completion {
    NSString *hostBundleId = [SimulatorHelper bundleIdForPath:self.config.appBundlePath];
    NSString *hostAppExecPath = [SimulatorHelper executablePathforPath:self.config.appBundlePath];

    // One bp instance only run one kind of xctest file.
    if (self.config.testRunnerAppPath) {
        hostAppExecPath = [SimulatorHelper executablePathforPath:self.config.testRunnerAppPath];
        hostBundleId = [SimulatorHelper bundleIdForPath:self.config.testRunnerAppPath];
    }
    // Create the environment for the host application
    NSMutableArray *commandLineArgs = [BPSimulator commandLineArgsFromConfig:self.config];
    NSMutableDictionary *argsAndEnv = [[NSMutableDictionary alloc] init];

    // These are appended by Xcode so we do that here.
    [commandLineArgs addObjectsFromArray:@[
                                           @"-NSTreatUnknownArgumentsAsOpen", @"NO",
                                           @"-ApplePersistenceIgnoreState", @"YES",
                                           @"-XCTIDEConnectionTimeout", @"180"
                                           ]];

    argsAndEnv[@"args"] = [commandLineArgs copy];
    argsAndEnv[@"env"] = self.config.environmentVariables ?: @{};

    // Intercept stdout, stderr and post as simulator-output events
    NSString *stdout_stderr = [NSString stringWithFormat:@"%@/tmp/stdout_stderr_%@", self.device.dataPath, [[self.device UDID] UUIDString]];
    NSString *simStdoutPath = [BPUtils mkstemp:stdout_stderr withError:nil];
    assert(simStdoutPath != nil);

    NSString *simStdoutRelativePath = [simStdoutPath substringFromIndex:((NSString *)self.device.dataPath).length];
    [[NSFileManager defaultManager] removeItemAtPath:simStdoutPath error:nil];

    // Create empty file so we can tail it and the app can write to it
    [[NSFileManager defaultManager] createFileAtPath:simStdoutPath
                                            contents:nil
                                          attributes:nil];

    self.appOutput = [NSFileHandle fileHandleForReadingAtPath:simStdoutPath];

    NSDictionary *appLaunchEnvironment = [SimulatorHelper appLaunchEnvironmentWithBundleID:hostBundleId device:self.device config:self.config];
    NSMutableDictionary *mutableAppLaunchEnv = [appLaunchEnvironment mutableCopy];
    NSString *insertLibraryPath = [NSString stringWithFormat:@"%@/Platforms/iPhoneSimulator.platform/Developer/usr/lib/libXCTestBundleInject.dylib", self.config.xcodePath];
    [mutableAppLaunchEnv setObject:insertLibraryPath forKey:@"DYLD_INSERT_LIBRARIES"];
    [mutableAppLaunchEnv setObject:insertLibraryPath forKey:@"XCInjectBundleInto"];
    [mutableAppLaunchEnv setObject:simStdoutRelativePath forKey:kOptionsStdoutKey];
    [mutableAppLaunchEnv setObject:simStdoutRelativePath forKey:kOptionsStderrKey];
    [mutableAppLaunchEnv addEntriesFromDictionary:argsAndEnv[@"env"]];
    if (self.config.testing_CrashAppOnLaunch) {
        mutableAppLaunchEnv[@"_BP_TEST_CRASH_ON_LAUNCH"] = @"YES";
    }
    if (self.config.testing_HangAppOnLaunch) {
        mutableAppLaunchEnv[@"_BP_TEST_HANG_ON_LAUNCH"] = @"YES";
    }
    if (self.config.testing_ExecutionPlan) {
        mutableAppLaunchEnv[@"_BP_TEST_EXECUTION_PLAN"] = self.config.testing_ExecutionPlan;
    }
    appLaunchEnvironment = [mutableAppLaunchEnv copy];
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

    [self.device launchApplicationAsyncWithID:hostBundleId options:options completionHandler:^(NSError *error, pid_t pid) {
        // Save the process ID to the monitor
        blockSelf.monitor.appPID = pid;
        blockSelf.monitor.appState = Running;

        [BPUtils printInfo:INFO withString:@"Launch succeeded"];

        if (error == nil) {
            [BPUtils printInfo:INFO withString:@"No error"];
            dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, pid, DISPATCH_PROC_EXIT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
            dispatch_source_set_event_handler(source, ^{
                dispatch_source_cancel(source);
            });
            dispatch_source_set_cancel_handler(source, ^{
                [blockSelf signalCloseToParser:parser fileHandle:[NSFileHandle fileHandleForWritingAtPath:simStdoutPath]];
                [blockSelf cleanUpParser:parser];
            });
            dispatch_resume(source);
            self.appOutput.readabilityHandler = ^(NSFileHandle *handle) {
                // This callback occurs on a background thread
                NSData *chunk = [handle availableData];
                [parser handleChunkData:chunk];
            };
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // Save the process ID to the monitor
            blockSelf.monitor.appPID = pid;

            [BPUtils printInfo:INFO withString:@"Completion block for launch"];
            if (completion) {
                [BPUtils printInfo:INFO withString:@"Calling completion block with: %@ - %d", error, pid];
                completion(error, pid);
            }
        });
    }];
}

- (void)deleteSimulatorWithCompletion:(void (^)(NSError *error, BOOL success))completion {
    NSError *error;
    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.config.xcodePath error:&error];
    SimDeviceSet *deviceSet = [sc defaultDeviceSetWithError:&error];
    if (!self.app && !self.device) {
        [BPUtils printInfo:ERROR withString:@"No device to delete"];
        completion(nil, NO);
        return;
    }
    if (self.device) {
        [BPUtils printInfo:INFO withString:@"Shutting down Simulator"];
        [self.device shutdownWithError:&error];
        if (error) {
            [BPUtils printInfo:ERROR withString:@"Shutting down Simulator failed: %@", [error localizedDescription]];
            completion(error, NO);
            return;
        }
    }
    // We need to wait until the simulator has shut down.
    int attempts = 300;
    while (attempts > 0 && ![self.device.stateString isEqualToString:@"Shutdown"]) {
        [NSThread sleepForTimeInterval:1.0];
        --attempts;
    }
    if (![self.device.stateString isEqualToString:@"Shutdown"]) {
        [BPUtils printInfo:ERROR withString:@"It may not be possible to delete simulator %@ in '%@' state.", self.device.name, self.device.stateString];
        // Go ahead and try to delete anyway
    }
    [deviceSet deleteDeviceAsync:self.device completionHandler:^(NSError *error) {
        if (error) {
            [BPUtils printInfo:ERROR withString:@"Could not delete simulator: %@", [error localizedDescription]];
        }
        completion(error, error ? NO: YES);
    }];
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

- (BOOL)isApplicationLaunched {
    return [self.monitor isApplicationLaunched];
}

- (BOOL)didTestStart {
    return [self.monitor didTestsStart];
}

- (BOOL)checkFinished {
    if ([self.monitor isExecutionComplete]) {
        switch ([self.monitor exitStatus]) {
            case BPExitStatusAllTestsPassed:
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

- (NSDictionary *)appInfo:(NSString *)bundleID withError:(NSError **)errPtr {
    NSDictionary *appInfo = [self.device propertiesOfApplication:bundleID error:errPtr];
    return appInfo;
}

- (void)setParserStateCompleted {
}

@end
