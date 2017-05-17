//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPConstants.h"
#import "BPPacker.h"
#import "BPXCTestFile.h"
#import "BPUtils.h"
#import "BPBundle.h"

@implementation BPPacker

+ (NSMutableArray *)packTests:(NSArray *)xcTestFiles
                configuration:(BPConfiguration *)config
                     andError:(NSError **)error {

    config = [BPPacker normalizeBPConfiguration:config withTestFiles:xcTestFiles];
    NSArray *testCasesToRun = config.testCasesToRun;
    NSArray *noSplit = config.noSplit;
    NSUInteger numBundles = [config.numSims integerValue];
    NSArray *sortedXCTestFiles = [xcTestFiles sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSUInteger numTests1 = [(BPXCTestFile *)obj1 numTests];
        NSUInteger numTests2 = [(BPXCTestFile *)obj2 numTests];
        return numTests2 - numTests1;
    }];
    if (sortedXCTestFiles.count == 0) {
        if (error) {
            *error = BP_ERROR(@"Found no XCTest files.\n"
                               "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.");
        }
        return NULL;
    }
    NSMutableDictionary *testsToRunByTestFilePath = [[NSMutableDictionary alloc] init];
    NSUInteger totalTests = 0;
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        if (![noSplit containsObject:[xctFile name]]) {
            NSMutableSet *bundleTestsToRun = [[NSMutableSet alloc] initWithArray:[xctFile allTestCases]];
            if (testCasesToRun) {
                [bundleTestsToRun intersectSet:[[NSSet alloc] initWithArray:testCasesToRun]];
            }
            if (config.testCasesToSkip) {
                [bundleTestsToRun minusSet:[[NSSet alloc] initWithArray:config.testCasesToSkip]];
            }
            if (bundleTestsToRun.count > 0) {
                testsToRunByTestFilePath[xctFile.path] = bundleTestsToRun;
                totalTests += bundleTestsToRun.count;
            }
        }
    }
    
    NSUInteger testsPerGroup = MAX(1, totalTests / numBundles);
    NSMutableArray *bundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        NSArray *bundleTestsToRun = [[testsToRunByTestFilePath[xctFile.path] allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger bundleTestsToRunCount = [bundleTestsToRun count];
        // if the xctfile is in nosplit list, don't pack it
        if ([noSplit containsObject:[xctFile name]] || (bundleTestsToRunCount <= testsPerGroup && bundleTestsToRunCount > 0)) {
            // just pack the whole xctest file and move on
            // testsToRun doesn't work reliably, switch to use testsToSkip
            // add testsToSkip from Bluepill runner's config to all BPBundle
            BPBundle *bundle = [[BPBundle alloc] initWithPath:xctFile.path isUITestBundle:xctFile.isUITestFile andTestsToSkip:config.testCasesToSkip];

            // Always insert no splited tests to the front.
            [bundles insertObject:bundle atIndex:0];
            continue;
        }

        // We don't want to pack tests from different xctest bundles so we just split
        // the current test bundle in chunks and pack those.
        NSArray *allTestCases = [[xctFile allTestCases] sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger packed = 0;
        while (packed < bundleTestsToRun.count) {
            NSRange range;
            range.location = packed;
            range.length = min(testsPerGroup, bundleTestsToRun.count - packed);
            NSMutableArray *testsToSkip = [NSMutableArray arrayWithArray:allTestCases];
            [testsToSkip removeObjectsInArray:[bundleTestsToRun subarrayWithRange:range]];
            [bundles addObject:[[BPBundle alloc] initWithPath:xctFile.path isUITestBundle:xctFile.isUITestFile andTestsToSkip:testsToSkip]];
            packed += range.length;
        }
        assert(packed == [bundleTestsToRun count]);
    }
    return bundles;
}

#pragma mark - Private helper methods

/*!

 @brief Updates the config to expand any testsuites in the tests-to-run/skip into their individual test cases.
 
 @discussion Bluepill supports passing in just the 'testsuite' as one of the tests to 'include' or 'exclude'.
 This method takes such items and expands them out so that the 'packTests:' method above can simply
 work with a list of fully qualified tests in the format of 'testsuite/testcase'.
 
 @param config the @c BPConfiguration for this bluepill-runner
 @param xcTestFiles an NSArray of BPXCTestFile's to retrieve the tests from
 @return an updated @c BPConfiguration with testCasesToSkip and testCasesToRun that have had testsuites fully expanded into a list of 'testsuite/testcases'

 */
+ (BPConfiguration *)normalizeBPConfiguration:(BPConfiguration *)config
                                withTestFiles:(NSArray *)xcTestFiles {
    
    config = [config mutableCopy];
    NSMutableSet *testsToRun = [NSMutableSet new];
    NSMutableSet *testsToSkip = [NSMutableSet new];
    for (BPXCTestFile *xctFile in xcTestFiles) {
        if (config.testCasesToRun) {
            [testsToRun unionSet:[BPPacker expandTests:config.testCasesToRun
                                          withTestFile:xctFile]];
        }
        if (config.testCasesToSkip) {
            [testsToSkip unionSet:[BPPacker expandTests:config.testCasesToSkip
                                           withTestFile:xctFile]];
        }
    }
    
    if (testsToRun.allObjects.count > 0) {
        config.testCasesToRun = testsToRun.allObjects;
    }
    config.testCasesToSkip = testsToSkip.allObjects;
    return config;
}

/*!
 @brief expand testcases into a list of fully expanded testcases in the form of 'testsuite/testcase'.
 
 @discussion searches the given .xctest bundle's entire list of actual testcases
 (that are in the form of 'testsuite/testcase') for testcases that belong to testsuites
 that were provided in the configTestCases.
 
 @param configTestCases a list of testcases: each item is either a 'testsuite' or a 'testsuite/testcase'.
 @param xctFile represents a .xctest bundle that contains the list of testcases available for that bundle.
 @return a @c NSMutableSet of all the expanded 'testsuite/testcase' items that match the given configTestCases.
 
 */
+ (NSMutableSet *)expandTests:(NSArray *)configTestCases withTestFile:(BPXCTestFile *)xctFile {
    NSMutableSet *expandedTests = [NSMutableSet new];
    
    for (NSString *testCase in configTestCases) {
        if ([testCase rangeOfString:@"/"].location == NSNotFound) {
            [xctFile.allTestCases enumerateObjectsUsingBlock:^(NSString *actualTestCase, NSUInteger idx, BOOL *stop) {
                if ([actualTestCase hasPrefix:[NSString stringWithFormat:@"%@/", testCase]]) {
                    [expandedTests addObject:actualTestCase];
                }
            }];
        } else {
            [expandedTests addObject:testCase];
        }
    }
    return expandedTests;
}


@end
