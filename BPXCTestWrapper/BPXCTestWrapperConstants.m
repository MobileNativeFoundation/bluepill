//
//  BPXCTestWrapperConstants.m
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 7/13/23.
//

#import "BPXCTestWrapperConstants.h"

@implementation BPXCTestWrapperConstants

+ (NSString *)dylibName {
    return @"libBPXCTestWrapper.dylib";
}

+ (NSString *)testBundleEnvironmentKey {
    return @"BP_XCTEST_WRAPPER__LOGIC_TEST_BUNDLE";
}

+ (NSString *)outputPathEnvironmentKey {
    return @"BP_XCTEST_WRAPPER__TEST_CASE_OUTPUT";
}

@end
