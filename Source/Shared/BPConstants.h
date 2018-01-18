//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

#define BP_DEFAULT_RUNTIME "iOS 11.2"
#define BP_DEFAULT_DEVICE_TYPE "iPhone 7"
#define BP_DEFAULT_XCODE_VERSION "Xcode 9.2"
#define BP_TM_PROTOCOL_VERSION 17
#define BP_DAEMON_PROTOCOL_VERSION 24
#define BP_MAX_PROCESSES_PERCENT 0.75


static const NSString * kCFBundleIdentifier = @"CFBundleIdentifier";
static const NSString * kOptionsArgumentsKey = @"arguments";
static const NSString * kOptionsEnvironmentKey = @"environment";
static const NSString * kOptionsStderrKey = @"stderr";
static const NSString * kOptionsStdoutKey = @"stdout";
static const NSString * kOptionsWaitForDebuggerKey = @"wait_for_debugger";

extern NSString * const BPErrorDomain;

extern NSString * const XCODE_BUILT_PRODUCTS_DIR;
extern NSString * const XCODE_EFFECTIVE_PLATFORM_NAME;
extern NSString * const XCODE_FULL_PRODUCT_NAME;
extern NSString * const XCODE_IPHONEOS_DEPLOYMENT_TARGET;
extern NSString * const XCODE_LAUNCH_TIMEOUT;
extern NSString * const XCODE_OBJROOT;
extern NSString * const XCODE_PLATFORM_DIR;
extern NSString * const XCODE_PLATFORM_NAME;
extern NSString * const XCODE_PRODUCT_MODULE_NAME;
extern NSString * const XCODE_PRODUCT_NAME;
extern NSString * const XCODE_PRODUCT_TYPE_FRAMEWORK_SEARCH_PATHS;
extern NSString * const XCODE_PROJECT_DIR;
extern NSString * const XCODE_SDK_NAME;
extern NSString * const XCODE_SDKROOT;
extern NSString * const XCODE_SHARED_PRECOMPS_DIR;
extern NSString * const XCODE_SYMROOT;
extern NSString * const XCODE_TARGET_BUILD_DIR;
extern NSString * const XCODE_TARGETED_DEVICE_FAMILY;
extern NSString * const XCODE_TEST_FRAMEWORK_SEARCH_PATHS;
