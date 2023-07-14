//
//  main.m
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 5/29/23.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

#import "BPXCTestUtils.h"
#import "BPLoggingUtils.h"
#import "BPXCTestWrapperConstants.h"

//void tearDown(int signal) {
//}

/**
 This wrapper around XCTest hijacks the process when two key env variables are set, hooking into the xctest process to
 instead get information on what tests exist in the test suite. This allows Bluepill to do two main things:
 
 1) It can create an aggregate timeout based on the number of tests to run
 2) It allows us to support opting-out of tests, rather than just opting in, as xctest provides no explicit opt-out api.
 
 When `BP_XCTEST_WRAPPER__LOGIC_TEST_BUNDLE` and `BP_XCTEST_WRAPPER__TEST_CASE_OUTPUT` are set,
 the entire process will only output an encoded file with test case info at the path specified by `BP_XCTEST_WRAPPER__TEST_CASE_OUTPUT`,
 and **no tests will actually be run**.
 
 When they are not set, tests will be run as normal with no other side effects.
 */
__attribute__((constructor))
static void didLoad() {
    [BPLoggingUtils log:@"Booting up the wrapper."];
    
    #if !TARGET_OS_IOS
    [BPLoggingUtils log:@"Returning."];
    return;
    #endif
    
    // Grab relavent info from environment
    NSString *bundlePath = NSProcessInfo.processInfo.environment[BPXCTestWrapperConstants.testBundleEnvironmentKey];
    NSString *outputPath = NSProcessInfo.processInfo.environment[BPXCTestWrapperConstants.outputPathEnvironmentKey];
    // Reset DYLD_INSERT_LIBRARIES and other env variables to avoid impacting future processes
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv(BPXCTestWrapperConstants.testBundleEnvironmentKey.UTF8String);
    unsetenv(BPXCTestWrapperConstants.outputPathEnvironmentKey.UTF8String);

    if (!bundlePath || !outputPath) {
        return;
    }
    [BPLoggingUtils log:[NSString stringWithFormat:@"Will enumerate all testCases in bundle at %@", bundlePath]];
    [BPXCTestUtils logAllTestsInBundleWithPath:bundlePath toFile:outputPath];
    // Once tests are logged, we want the process to end.
    exit(0);
}

//__attribute__((destructor)) static void pluginDidUnload() {
//    tearDown(0);
//}
