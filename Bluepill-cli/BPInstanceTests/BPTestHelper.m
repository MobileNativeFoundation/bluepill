//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTestHelper.h"

@implementation BPTestHelper

// Return the path to the sample app directory (path to XX.app)
+ (NSString *)sampleAppPath {
    return [[self bpDerivedDataPath] stringByAppendingString:@"/BPSampleApp.app"];
}

// Return the path to the sample app's xctest with 1000 test cases
+ (NSString *)sampleAppBalancingTestsBunldePath {
    return [[self sampleAppPath] stringByAppendingString:@"/Plugins/BPSampleAppTests.xctest"];
}

// Return the path to the sample app's xctest with different kinds of negative tests
+ (NSString *)sampleAppNegativeTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/Plugins/BPAppNegativeTests.xctest"];
}

+ (NSString *)sampleAppCrashingTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/Plugins/BPSampleAppCrashingTests.xctest"];
}

+ (NSString *)sampleAppHangingTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/Plugins/BPSampleAppHangingTests.xctest"];
}

+ (NSString *)sampleAppFatalTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/Plugins/BPSampleAppFatalErrorTests.xctest"];
}

+ (NSString *)resourceFolderPath {
    return [[NSBundle bundleForClass:[self class]] resourcePath];
}

+ (NSString *)bpExecutablePath {
    return [[[[NSBundle bundleForClass:[self class]] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"bp"];
}

#pragma mark - Helpers

+ (NSString *)bpDerivedDataPath {
    NSString *currentPath = [[NSBundle bundleForClass:[self class]] bundlePath];
    return [[[currentPath stringByDeletingLastPathComponent]
            stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Debug-iphonesimulator"];
}

@end
