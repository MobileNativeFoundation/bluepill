//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

#define BP_DEFAULT_RUNTIME "iOS 10.1"
#define BP_DEFAULT_DEVICE_TYPE "iPhone 6"

static const NSString * kCFBundleIdentifier = @"CFBundleIdentifier";
static const NSString * kOptionsArgumentsKey = @"arguments";
static const NSString * kOptionsEnvironmentKey = @"environment";
static const NSString * kOptionsStderrKey = @"stderr";
static const NSString * kOptionsStdoutKey = @"stdout";
static const NSString * kOptionsWaitForDebuggerKey = @"wait_for_debugger";

extern NSString * const BPErrorDomain;

extern NSString * const Xcode_BUILT_PRODUCTS_DIR;
extern NSString * const Xcode_EFFECTIVE_PLATFORM_NAME;
extern NSString * const Xcode_FULL_PRODUCT_NAME;
extern NSString * const Xcode_IPHONEOS_DEPLOYMENT_TARGET;
extern NSString * const Xcode_LAUNCH_TIMEOUT;
extern NSString * const Xcode_OBJROOT;
extern NSString * const Xcode_PLATFORM_DIR;
extern NSString * const Xcode_PLATFORM_NAME;
extern NSString * const Xcode_PRODUCT_MODULE_NAME;
extern NSString * const Xcode_PRODUCT_NAME;
extern NSString * const Xcode_PRODUCT_TYPE_FRAMEWORK_SEARCH_PATHS;
extern NSString * const Xcode_PROJECT_DIR;
extern NSString * const Xcode_SDK_NAME;
extern NSString * const Xcode_SDKROOT;
extern NSString * const Xcode_SHARED_PRECOMPS_DIR;
extern NSString * const Xcode_SYMROOT;
extern NSString * const Xcode_TARGET_BUILD_DIR;
extern NSString * const Xcode_TARGETED_DEVICE_FAMILY;
extern NSString * const Xcode_TEST_FRAMEWORK_SEARCH_PATHS;
