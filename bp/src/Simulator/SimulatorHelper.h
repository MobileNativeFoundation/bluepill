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
 * @discussion load the required frameworks
 * @param xcodePath path to the xcode.app/contents
 * @return return whether the frameworks are successfully loaded or not.
 */
+ (BOOL)loadFrameworksWithXcodePath:(NSString *)xcodePath;

/*!
 * @discussion get app launch environment
 * @param hostBundleID the bundleID of the host app
 * @param device the device to run test
 * @param config the configuration object
 * @return returns the app launch environment as a dictionary
 */
+ (NSDictionary *)appLaunchEnvironmentWithBundleID:(NSString *)hostBundleID
                                            device:(SimDevice *)device
                                            config:(BPConfiguration *)config;

/*!
 * @discussion get the path of the environment configuration file
 * @return return the path to the test configuration file.
 */
+ (NSString *)testEnvironmentWithConfiguration:(BPConfiguration *)config;

#pragma mark - Path Helper

+ (NSString *)bundleIdForPath:(NSString *)path;
+ (NSString *)executablePathforPath:(NSString *)path;
+ (NSString *)appNameForPath:(NSString *)path;

@end
