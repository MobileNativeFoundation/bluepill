//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.


#define min(a, b) ({ \
__typeof__(a) _a = (a); \
__typeof__(b) _b = (b); \
_a < _b ? _a : _b; \
})

#import <Foundation/Foundation.h>
#import "BPXCTestFile.h"

typedef NS_ENUM(int, BPKind) {
    PASSED,
    FAILED,
    TIMEOUT,
    INFO,
    ERROR,
    WARNING,
    CRASH,
    DEBUGINFO // DEBUG collides with a #define, so DEBUGINFO it is
};

@class BPConfiguration;
@class BPExecutionContext;

@interface BPUtils : NSObject

/*!
 @discussion enable debugging messages
 @param enable True enables debugging, False disables it.
 */
+ (void)enableDebugOutput:(BOOL)enable;

/*!
 @discussion omit all output except fatal errors
 @param enable True enables quiet mode, False disables it.
 */
+ (void)quietMode:(BOOL)enable;

/*!
 @discussion returns true if the environment variable `BPBuildScript` is set to `YES`
 which indicates that the application is running via the build script
 */
+ (BOOL)isBuildScript;

+ (NSString *)findBPXCTestWrapperDYLIB;

+ (NSString *)findExecutablePath:(NSString *)execName;

/*!
 @discussion creates a temporary directory via mkdtemp(3)
 @param pathTemplate a path in which to create the temporary directory.
 It doesn't need to be unique since a unique identifier will be appended
 to it.
 @param errPtr an error if creating the temporary directory failed.
 @return the path of the temporary directory created.
 */
+ (NSString *)mkdtemp:(NSString *)pathTemplate withError:(NSError **)errPtr;

/*!
 @discussion returns a temporary path name via mkstemp(3)
 @param pathTemplate the path of the temporary file. It doesn't need to be
 unique since a unique identifier will be appended.
 @param errPtr an error if creating the temporary file name failed.
 @return the path of the temporary file.
 */
+ (NSString *)mkstemp:(NSString *)pathTemplate withError:(NSError **)errPtr;

/*!
 @discussion print a message to stdout.
 @param kind one of the levels in BPKind
 @param fmt a format string (a la printf), followed by the var args.
 */
+ (void)printInfo:(BPKind)kind withString:(NSString *)fmt, ... NS_FORMAT_FUNCTION(2,3);

/*!
 Creates an `NSError *` with BP-specific domain for a given signal code, updating the description accordingly.
 @param signalCode The signal code.
 */
+ (NSError *)errorWithSignalCode:(NSInteger)signalCode;

/*!
 Creates an `NSError *` with BP-specific domain for a given exit code, updating the description accordingly.
 @param exitCode The exit code.
 */
+ (NSError *)errorWithExitCode:(NSInteger)exitCode;

/*!
 @discussion get an `NSError *`
 This is not really meant to be called, use the `BP_SET_ERROR` macro below instead.
 @param function The name of the function
 @param line The line number
 @param fmt a format string (a la printf), followed by var args.
 */
+ (NSError *)BPError:(const char *)function andLine:(int)line withFormat:(NSString *)fmt, ... ;

#define VA_ARGS(...) , ##__VA_ARGS__
#define BP_SET_ERROR(error, fmt, ...) { \
    if (error) { \
        *error = [BPUtils BPError:__func__ andLine:__LINE__ withFormat:fmt VA_ARGS(__VA_ARGS__)]; \
    } \
}

/*!

 @brief Updates the config to expand any testsuites in the tests-to-run/skip into their individual test cases.

 @discussion Bluepill supports passing in just the 'testsuite' as one of the tests to 'include' or 'exclude'.
 This method takes such items and expands them out so that @c BPPacker and @c SimulatorHelper can simply
 work with a list of fully qualified tests in the format of 'testsuite/testcase'.

 @param config the @c BPConfiguration for this bluepill-runner
 @param xctTestFiles an NSArray of BPXCTestFile's to retrieve the tests from
 @return an updated @c BPConfiguration with testCasesToSkip and testCasesToRun that have had testsuites fully expanded into a list of 'testsuite/testcases'

 */
+ (BPConfiguration *)normalizeConfiguration:(BPConfiguration *)config
                              withTestFiles:(NSArray *)xctTestFiles;

/*!
 Returns an aggregated timeout interval for all tests to be run in an execution. While we will
 still apply a per-test timeout, it's possible for things to fail in an XCTest execution when a test isn't
 being run, and we want to make sure the execution still fails when this occurs.
 
 @discussion This timeout value is based on the timeout per test multiplied by the number of tests,
 with an additional buffer per test.
 @param config The fully setup configuration that will be used to calculate the aggregate timeout.
 @return The aggregated timeout.
 */
+ (double)timeoutForAllTestsWithConfiguration:(BPConfiguration *)config;

/*!
 @discussion a function to determine if the given file name represents
 stdout. A file name is considered stdout if it is '-' or 'stdout'.
 @param fileName the file name to check.
 @return whether it's stdout.
 */
+ (BOOL)isStdOut: (NSString *)fileName;

/*!
 * @discussion run a shell command and return the output
 * @param command the shell command to run
 * @return return the shell output
 */
+ (NSString *)runShell:(NSString *)command;

/*!
 * @discussion builds a task to run a shell command
 * @param command the shell command the task should run
 * @return an NSTask that will run the provided command.
 */
+ (NSTask *)buildShellTaskForCommand:(NSString *)command;

/*!
 * @discussion builds a task to run a shell command, pointing stdout and stderr to the provided pipe
 * @param command the shell command the task should run
 * @param pipe the pipe that stdout and stderr will be pointed to, so the caller can handle the output.
 * @return an NSTask that will run the provided command.
 */
+ (NSTask *)buildShellTaskForCommand:(NSString *)command withPipe:(NSPipe *)pipe;

/*!
 * @discussion builds a user readable representation of the command that a task is configured to run
 * @param task to get command from
 * @return a user readable string of the task's command
*/
+ (NSString *)getCommandStringForTask:(NSTask *)task;

+ (NSString *)getXcodeRuntimeVersion;

typedef BOOL (^BPRunBlock)(void);

/*!
 * @discussion spin block till either it returns YES or timeout.
 * @param time timeout time
 * @param block the block to run
 * @return return whether the block returns YES or not.
 */
+ (BOOL)runWithTimeOut:(NSTimeInterval)time until:(BPRunBlock)block;

/*!
 * @discussion save debugging statistics in output directory
 * @param outputDirectory where to save the diagnostics
 */
+ (void)saveDebuggingDiagnostics:(NSString *)outputDirectory;

/*!
 * @discussion removing arguments from inside parenthesis from test names from the extracted symbols
 * @param testName the name of the test to trim
 * @return trimmed test name
 */
+ (NSString *)removeSwiftArgumentsFromTestName:(NSString *)testName;

/*!
 * @discussion Checks for indicators that a test name is a swift test's name, i.e. has `<bundle>.` or `()`
 * @param testName the name of the test to check
 * @return `YES` if swift, `NO` if objc
 */
+ (BOOL)isTestSwiftTest:(NSString *)testName;

/*!
 * @discussion Strips the test's bundle name if present, and adds in parenthesis. This is
 * the format that consumers of Bluepill expect to provide + see in test reports.
 * @param testName the name of the test to format
 * @return trimmed test name
 */
+ (NSString *)formatSwiftTestForReport:(NSString *)testName;

/*!
 * @discussion XCTest requires that swift test names are fully namespaced, and don't include parens,
 * contrary to what Bluepill consumers provide.
 *
 * @param testName the name of the test to format
 * @param bundleName The name of the test's bundle
 * @return trimmed test name
 */
+ (NSString *)formatSwiftTestForXCTest:(NSString *)testName withBundleName:(NSString *)bundleName;

/*!
 * @discussion setup the environment for weak linked frameworks
 * @param argc the number of arguments to the command
 * @param argv the arguments to the command
 * @return exit code 0 == success
 */
+ (int)setupWeakLinking:(int)argc argv:(char **)argv;

/*!
 * @discussion return the version of bplib
 * @return the version
 */
+ (char *)version;

/*!
 * @discussion loads json mapping file from given absolute path
 * @param filePath the absolute path of the input json mapping file
 * @param errPtr an error if loading json mapping fails for some reason
 * @return a dictionary with the mappings
 */
+ (NSDictionary *)loadSimpleJsonFile:(NSString *)filePath withError:(NSError **)errPtr;

/*!
 * @discussion Get total time from config.
 * @param config The configuration file for this bluepill-runner
 * @param testTimes Mapping of a test name to it's estimated execution time
 * @param xcTestFiles An NSArray of BPXCTestFile's to pack
 * @return The total time to run all the tests
 */
+ (double)getTotalTimeWithConfig:(BPConfiguration *)config
                       testTimes:(NSDictionary<NSString *,NSNumber *> *)testTimes
                  andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles;

/*!
 * @discussion Get a set of tests to run by file path.
 * @param config The configuration file for this bluepill-runner
 * @param xcTestFiles An NSArray of BPXCTestFile's to pack
 * @return A dictionary of file path to set of tests mapping
 */
+ (NSDictionary<NSString *, NSSet *> *)getTestsToRunByFilePathWithConfig:(BPConfiguration *)config
                                                          andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles;

/*!
 * @discussion Get test estimates by file path.
 * @param config The configuration file for this bluepill-runner
 * @param testTimes Mapping of a test name to it's estimated execution time
 * @param xcTestFiles An NSArray of BPXCTestFile's to pack
 * @return A dictionary of file patn to total time estimate mapping
 */
+ (NSDictionary<NSString *,NSNumber *> *)getTestEstimatesByFilePathWithConfig:(BPConfiguration *)config
                                                                    testTimes:(NSDictionary<NSString *,NSNumber *> *)testTimes
                                                               andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles;

#pragma mark - Logic Test Architecture Helpers

/**
 We can isolate a single architecture out of a universal binary using the `lipo -extract` command. By doing so, we can
 force an executable (such as XCTest) to always run w/ the architecture we expect. This is to avoid some funny business where
 the architecture selected can be unexpected depending on multiple factors, such as Rosetta, xcode version, etc.
 
 @return the path of the new executable if possible + required, nil otherwise. In nil case, original executable should be used instead.
 */
+ (NSString *)lipoExecutableAtPath:(NSString *)path withContext:(BPExecutionContext *)context;

/**
 Lipo'ing the universal binary alone to isolate the desired architecture will result in errors.
 Specifically, the newly lipo'ed binary won't be able to find any of the required frameworks
 from within the original binary. So, we need to set up the `DYLD_FRAMEWORK_PATH`
 in the environment to include the paths to these frameworks within the original universal
 executable's binary.
 */
+ (NSString *)correctedDYLDFrameworkPathFromBinary:(NSString *)binaryPath;

@end
