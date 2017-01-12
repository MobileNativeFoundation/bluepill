//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "SimDevice.h"
@class BPConfiguration;

@interface SimulatorHelper : NSObject

/*!
 * @discussion get app launch environment
 * @param hostAppPath the path to the host application /ABC.app/ABC
 * @param testBundlePath the path to the test bundle /ABC.app/scheme.xctest
 * @param config the configuration object
 * @return returns the app launch environment as a dictionary
 */
+ (NSDictionary *)appLaunchEnvironmentWith:(NSString *)hostAppPath
                            testbundlePath:(NSString *)testBundlePath
                                    config:(BPConfiguration *)config;

/*!
 * @discussion get the path of the environment configuration file
 * @return return the path to the test configuration file.
 */
+ (NSString *)testEnvironmentWithConfiguration:(BPConfiguration *)config;

+ (NSString *)bundleIdForPath:(NSString *)path;
+ (NSString *)executablePathforPath:(NSString *)path;
+ (NSString *)appNameForPath:(NSString *)path;

@end
