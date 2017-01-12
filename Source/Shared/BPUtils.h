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
+ (void)printInfo:(BPKind)kind withString:(NSString *)fmt, ...;

/*!
 @discussion print a message to stderr.
 @param kind one of the levels in BPKind
 @param fmt a format string (a la printf), followed by the var args.
 */
+ (void)printError:(BPKind)kind withString:(NSString *)fmt, ...;

/*!
 @discussion a function to determine if the given file name represents
 stdout. A file name is considered stdout if it is '-' or 'stdout'.
 @param fileName the file name to check.
 @return whether it's stdout.
 */
+ (BOOL)isStdOut: (NSString *)fileName;


// Scheme parsing

/*!
 * @discussion return the build arguments and environment
 * @param schemePath the path to the scheme file
 * @return return the ArgsAndEnvironement as a dictionary:
 *          @{@"args":@[argument_list], @"env":@{env_dictionary}}
 */
+ (NSDictionary *)buildArgsAndEnvironmentWith:(NSString *)schemePath;
+ (NSString *)runShell:(NSString *)command;

@end
