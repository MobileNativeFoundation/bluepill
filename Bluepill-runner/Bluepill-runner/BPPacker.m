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
            BPBundle *bundle = [[BPBundle alloc] initWithPath:xctFile.path isUITestBundle:xctFile.isUITestFile andTestsToSkip:@[]];

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

@end
