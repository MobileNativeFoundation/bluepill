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
    return [[self debugIphoneSimulatorPath] stringByAppendingString:@"/BPSampleApp.app"];
}

+ (NSString *)sampleTestScheme {
    NSString *path = @"testScheme.xcscheme";
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
}

// Return the path to the sample app's xctest with 1000 test cases
+ (NSString *)sampleAppBalancingTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/PlugIns/BPSampleAppTests.xctest"];
}

// Return the path to the sample app's xctest with different kinds of negative tests
+ (NSString *)sampleAppNegativeTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/PlugIns/BPAppNegativeTests.xctest"];
}

+ (NSString *)sampleAppCrashingTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/PlugIns/BPSampleAppCrashingTests.xctest"];
}

+ (NSString *)sampleAppHangingTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/PlugIns/BPSampleAppHangingTests.xctest"];
}

+ (NSString *)sampleAppFatalTestsBundlePath {
    return [[self sampleAppPath] stringByAppendingString:@"/PlugIns/BPSampleAppFatalErrorTests.xctest"];
}

+ (NSString *)resourceFolderPath {
    return [[NSBundle bundleForClass:[self class]] resourcePath];
}

// Return the path to the XCTRunner
+ (NSString *)sampleAppUITestRunnerPath {
    return [[[self sampleAppPath] stringByDeletingLastPathComponent] stringByAppendingString:@"/BPSampleAppUITests-Runner.app/"];
}

// Return the path to the XCTRunner
+ (NSString *)sampleAppUITestBundlePath {
    return [[self sampleAppUITestRunnerPath] stringByAppendingString:@"/PlugIns/BPSampleAppUITests.xctest"];
}

+ (NSString *)sampleVideoPath {
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"demo.mov"];
}

+ (NSString *)samplePhotoPath {
    return [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"image.png"];
}

+ (NSString *)bpExecutablePath {
    return [[self debugMacOSPath] stringByAppendingPathComponent:@"bp"];
}

#pragma mark - Helpers

+ (NSString *)derivedDataPath {
    // As a result of moving BluepillLib to a separate target, it no longer sits together with bp or bluepill binary but inside a ./build/Bluepill/Build/Intermediates.noindex/UninstalledProducts/ directory.
    return [[[[[[NSBundle bundleForClass:[self class]] bundlePath] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
}

+ (NSString *)debugIphoneSimulatorPath {
    return [[self derivedDataPath] stringByAppendingPathComponent:@"Products/Debug-iphonesimulator"];
}

+ (NSString *)debugMacOSPath {
    return [[self derivedDataPath] stringByAppendingPathComponent:@"Products/Debug"];
}

@end
