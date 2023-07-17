//
//  BPTestInspectorConstants.m
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 7/13/23.
//

#import "BPTestInspectorConstants.h"

@implementation BPTestInspectorConstants

+ (NSString *)dylibName {
    return @"libBPTestInspector.dylib";
}

+ (NSString *)testBundleEnvironmentKey {
    return @"BP_XCTEST_WRAPPER__LOGIC_TEST_BUNDLE";
}

+ (NSString *)outputPathEnvironmentKey {
    return @"BP_XCTEST_WRAPPER__TEST_CASE_OUTPUT";
}

@end
