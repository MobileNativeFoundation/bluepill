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

/*!
 @discussion creates a temporary directory via mkdtemp(3)
 @param pathTemplate a path in which to create the temporary directory.
 It doesn't need to be unique since a unique identifier will be appended 
 to it.
 @param error an error if creating the temporary directory failed.
 @return the path of the temporary directory created.
 */
+ (NSString *)mkdtemp:(NSString *)pathTemplate withError:(NSError **)error;

/*!
 @discussion returns a temporary path name via mkstemp(3)
 @param pathTemplate the path of the temporary file. It doesn't need to be
 unique since a unique identifier will be appended.
 @param error an error if creating the temporary file name failed.
 @return the path of the temporary file.
 */
+ (NSString *)mkstemp:(NSString *)pathTemplate withError:(NSError **)error;


/*!
 @discussion print a message to stdout.
 @param kind one of the levels in BPKind
 @param fmt a format string (a la printf), followed by the var args.
 */
+ (void)printInfo:(BPKind)kind withString:(NSString *)fmt, ... NS_FORMAT_FUNCTION(2,3);

/*!
 @discussion get an NSError *
 This is not really meant to be called, use the BP_SET_ERROR macro below instead.
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

@end
