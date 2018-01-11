//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPConstants.h"
// Only `bp` uses the CoreSimulator private frameworks.
#ifdef BP_USE_PRIVATE_FRAMEWORKS
#import "CoreSimulator.h"
#endif

/**
 BPConfiguration stores necessary information for Simulator Runner to run
 */

@interface BPConfiguration : NSObject <NSCopying>

typedef NS_ENUM(NSInteger, BPProgram) {
    BP_MASTER = 1,
    BP_SLAVE = 2,
};

/*
 * WARNING: Any fields you add here need to be explicitly handled in the copyWithZone
 * and mutableCopyWithZone methods. Yeah, it's stupid, we should fix it.
 */

@property (nonatomic, strong) NSUUID *sessionIdentifier;
@property (nonatomic, strong) NSString *appBundlePath;

// XCUITest sector
@property (nonatomic, strong) NSString *testRunnerAppPath;
@property (nonatomic, strong) NSArray *additionalUITestBundles;

// XCTest sector
@property (nonatomic, strong) NSArray *additionalUnitTestBundles;

// Common
@property (nonatomic, strong) NSString *testBundlePath;
@property (nonatomic, strong) NSString *deviceType;
@property (nonatomic, strong) NSString *runtime;
@property (nonatomic, strong) NSString *configFile;
@property (nonatomic, strong) NSString *schemePath;
@property (nonatomic, strong) NSString *xcTestRunPath;
@property (nonatomic, strong) NSDictionary *xcTestRunDict; // parsed copy of the path above.
@property (nonatomic, strong) NSMutableArray *bpCmdLineArgs; // command line arguments passed to bluepill
@property (nonatomic, strong) NSNumber *repeatTestsCount;
@property (nonatomic, strong) NSNumber *errorRetriesCount;
@property (nonatomic, strong) NSNumber *stuckTimeout;
@property (nonatomic, strong) NSNumber *testCaseTimeout;
@property (nonatomic, strong) NSArray *noSplit;
@property (nonatomic) BOOL junitOutput;
@property (nonatomic) BOOL plainOutput;
@property (nonatomic) BOOL jsonOutput;
@property (nonatomic) BOOL saveDiagnosticsOnError;
@property (nonatomic, strong) NSNumber *failureTolerance;
@property (nonatomic) BOOL onlyRetryFailed;
@property (nonatomic, strong) NSArray *testCasesToSkip;
@property (nonatomic, strong) NSArray *testCasesToRun;
@property (nonatomic, strong) NSArray *allTestCases;
@property (nonatomic, strong) NSString *configOutputFile;
@property (nonatomic, strong) NSString *outputDirectory;
@property (nonatomic, strong) NSString *screenshotsDirectory;
@property (nonatomic) BOOL headlessMode;
@property (nonatomic, strong) NSNumber *numSims;
@property (nonatomic) BOOL listTestsOnly;
@property (nonatomic) BOOL quiet;
@property (nonatomic, strong) NSString *useSimUDID;
@property (nonatomic, strong) NSString *deleteSimUDID;
@property (nonatomic) BOOL keepSimulator;
@property (nonatomic) BOOL reuseSimulator;
@property (nonatomic) BPProgram program; // one of BP_MASTER or BP_SLAVE
@property (nonatomic) BOOL verboseLogging;
@property (nonatomic, strong) NSNumber *maxCreateTries;
@property (nonatomic, strong) NSNumber *maxInstallTries;
@property (nonatomic, strong) NSNumber *maxLaunchTries;
@property (nonatomic, strong) NSNumber *createTimeout;
@property (nonatomic, strong) NSNumber *launchTimeout;
@property (nonatomic, strong) NSNumber *deleteTimeout;

@property (nonatomic, strong) NSArray<NSString *> *commandLineArguments; // command line arguments for the app
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *environmentVariables;

// Media Assets
@property (nonatomic, strong) NSArray<NSString *> *videoPaths; // The videos to be pushed into each simulator.
@property (nonatomic, strong) NSArray<NSString *> *imagePaths; // The images to be pushed into each simulator.

// These fields are for testing.
@property (nonatomic) BOOL testing_Environment;
@property (nonatomic) BOOL testing_CrashAppOnLaunch;
@property (nonatomic) BOOL testing_HangAppOnLaunch;
@property (nonatomic) BOOL testing_NoAppWillRun;

// Generated fields
@property (nonatomic, strong) NSString *xcodePath;

#ifdef BP_USE_PRIVATE_FRAMEWORKS
@property (nonatomic, strong) SimDeviceType *simDeviceType;
@property (nonatomic, strong) SimRuntime *simRuntime;
#endif


/**
 Return a structure suitable for passing to `getopt()`'s long options.

 @return A pointer to a `struct option` suitable for `getopt()`.
 */
- (struct option *)getLongOptions;

/**
 Return a string of short options.

 @return A string suitable for `getopt()`.
 */
- (char *)getShortOptions;


/**
 Print usage and exit.

 @param rc Exit code for the process.
 */
- (void)usage:(int)rc;

/**
 Print the current configuration to standard output in a 
 format suitable for reading it again via the `-c` option.
 */
- (void)printConfig;

/**
 Handle the deferred processing of options. See `saveOpt`.

 @param err The error message in case processing the options fails.

 @return True if we managed to process the options successfully. False otherwise.
 */
- (BOOL)processOptionsWithError:(NSError **)err;

/**
 Validate that the current configuration would work with Bluepill.
 
 This tests simple things like paths are valid, devices/runtimes exist, etc.

 @param err The error message in case of failure.

 @return True if the configuration is valid. False otherwise.
 */
- (BOOL)validateConfigWithError:(NSError **)err;

/**
 Create a new configuration object with default values.
 
 @param program One of BLUEPILL or BP
 
 @return An instance of `BPConfiguration` on success. Nil on failure.
 */
- (instancetype)initWithProgram:(int)program;

/**
 Create a new configuration object based on the given configuration file. 
 
 Note that this function only loads the configuration, it doesn't perform 
 any validation. For that, call `validateConfigWithError:`

 @param file The file to load (nil will init a config object with defaults)
 @param program Which program is calling this? Bluepill or Bp
 @param err  The error in case loading the config file fails.

 @return An instance of `BPConfiguration` on success. Nil on failure.
 */
- (instancetype)initWithConfigFile:(NSString *)file forProgram:(BPProgram)program withError:(NSError **)err;

/**
 Save a command line option for later processing.

 @param opt A single option for processing (typically from a `getopt()` loop)
 @param arg The optional argument (typically optarg). Note it cannot be NULL.
 */
- (void)saveOpt:(NSNumber *)opt withArg:(NSString *)arg;

/**
 Copy a configuration object.

 @param zone zone

 @return A copy of the configuration object.
 */
- (id)copyWithZone:(NSZone *)zone;

/**
 Copy a configuration object (mutable).

 @param zone zone

 @return A mutable copy of the configuration object.
 */
- (id)mutableCopyWithZone: (NSZone *) zone;

@end
