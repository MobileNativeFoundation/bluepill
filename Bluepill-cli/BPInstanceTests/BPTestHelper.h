//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@interface BPTestHelper : NSObject

// Return the path to the sample app directory (path to XX.app)
+ (NSString *)sampleAppPath;

// Return the path to the test scheme
+ (NSString *)sampleTestScheme;

// Return the path to the sample app's xctest with 1000 test cases
+ (NSString *)sampleAppBalancingTestsBundlePath;

// Return the path to the sample app's xctest with failing tests. (no uncaught exception)
+ (NSString *)sampleAppNegativeTestsBundlePath;

// Return the path to the sample app's xctest with crashing tests.
+ (NSString *)sampleAppCrashingTestsBundlePath;

// Return the path to the sample app's xctest with crashing tests.
+ (NSString *)sampleAppHangingTestsBundlePath;

// Return the path to the sample app's xctest with testcase timeout tests.
+ (NSString *)sampleAppTestTimeoutTests;

// Return the path to the sample app's xctest with crashing tests.
+ (NSString *)sampleAppFatalTestsBundlePath;

// Return the path to the XCTRunner
+ (NSString *)sampleAppUITestRunnerPath;

// Return the path to the XCTRunner
+ (NSString *)sampleAppUITestBundlePath;

// Return the path to the resource folder
+ (NSString *)resourceFolderPath;

// Return the path to the bp executable
+ (NSString *)bpExecutablePath;

// Return the derivedDataPath
+ (NSString *)derivedDataPath;

// Return path to the sample video file.
+ (NSString *)sampleVideoPath;

// Return the sample photo path.
+ (NSString *)samplePhotoPath;

@end
