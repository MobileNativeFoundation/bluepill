//
//  bp_test_dumper.m
//  bp_test_dumper
//
//  Created by Ravi K. Mandala on 10/23/19.
//  Copyright © 2019 LinkedIn. All rights reserved.
//
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#define OUTPUT_FILE_PATH "_BP_TEST_LIST_FILE"

NSString *getSimpleName(NSString *testName) {
    // Extracting test name from a string like "-[FeedHighlightedUpdateTrackingTest testFeedHighlightedUpdateEvent]"
    NSString *simpleTestName = [testName componentsSeparatedByString:@" "][1];
    simpleTestName = [simpleTestName substringToIndex:simpleTestName.length-1];
    return simpleTestName;
}

/* Return code:
 * 0 - Successful
 * 1 - Error loading the test bundles
 * 2 - Error writing output file
 */
__attribute__((constructor))
void read_it() {
    NSString *outputFilePath = [[NSProcessInfo processInfo] environment][@OUTPUT_FILE_PATH];
    if (!outputFilePath) {
        NSLog(@"[BPTestDumper] Environment variable for Output file path not set. Please set %@ and try again.", @OUTPUT_FILE_PATH);
        exit(2);
    }
    NSLog(@"[BPTestDumper] Output test dump file path is %@", outputFilePath);
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *pluginsPath = [mainBundle builtInPlugInsPath];
    NSArray *xcTests = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:Nil];
    NSLog(@"[BPTestDumper] Got a total of %lu xctest bundles.", [xcTests count]);
    for (NSString *xcTestBundlePath in xcTests) {
        NSString *ext = [xcTestBundlePath pathExtension];
        if (![ext isEqual:@"xctest"]) {
            NSLog(@"[BPTestDumper] Skipping %@ - %@", xcTestBundlePath, ext);
            continue;
        }
        NSString *path = [pluginsPath stringByAppendingPathComponent:xcTestBundlePath];
        NSLog(@"[BPTestDumper] Loading %@", path);
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (!bundle) {
            NSLog(@"[BPTestDumper] bundle failed to load!");
            perror("bundle");
            exit(1);
        }
        [bundle load];
    }
    NSLog(@"[BPTestDumper] Creating a default test suite with all suites of suites...");
    XCTestSuite *defaultTestSuite = [XCTestSuite defaultTestSuite];
    if (!defaultTestSuite) {
        NSLog(@"[BPTestDumper] Failed to create a defaultTestSuite");
        exit(1);
    }
    NSLog(@"[BPTestDumper] Successfully created a defaultTestSuite!");
    NSMutableDictionary *testInfoDict = [[NSMutableDictionary alloc] init];
    for (XCTestSuite *testSuite in [defaultTestSuite tests]) {
        NSLog(@"[BPTestDumper] Parsing test bundle - %@; Number of test classes = %lu", [testSuite name], [testSuite testCaseCount]);
        NSMutableDictionary *testClassesDict = [[NSMutableDictionary alloc] init];
        for (XCTestSuite *testClass in [testSuite tests]) {
            NSMutableArray *testCaseList = [[NSMutableArray alloc] init];
            NSLog(@"[BPTestDumper] Parsing test class - %@; Number of test cases = %lu", [testClass name], [testClass testCaseCount]);
            for (XCTest *testCase in [testClass tests]) {
                NSLog(@"[BPTestDumper] Test case: %@", getSimpleName([testCase name]));
                [testCaseList addObject:getSimpleName([testCase name])];
            }
            if ([testCaseList count] > 0) {
                [testClassesDict setObject:(NSArray *)testCaseList forKey:[testClass name]];
            }
        }
        if ([testClassesDict count] > 0) {
            [testInfoDict setValue:testClassesDict forKey:[testSuite name]];
        }
    }
    NSError *err;
    NSData *json = [NSJSONSerialization dataWithJSONObject:testInfoDict
                                                   options:NSJSONWritingPrettyPrinted
                                                     error:&err];
    if (!json) {
        NSLog(@"[BPTestDumper] ERROR: %@", [err localizedDescription]);
        exit(2);
    }
    if (![json writeToFile:outputFilePath atomically:YES]) {
        NSLog(@"[BPTestDumper] Failed to dump the test list");
        exit(2);
    }
    NSLog(@"[BPTestDumper] Successfully dumped a list of tests into the output file: %@", outputFilePath);
    // don't actually run the app
    exit(0);
}
