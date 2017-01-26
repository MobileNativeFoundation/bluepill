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

+ (NSMutableArray *)packTests:(NSArray *)xcTestFiles withNoSplitList:(NSArray *)noSplit intoBundles:(NSUInteger)numBundles andError:(NSError **)error {
    NSUInteger totalTests = 0;
    NSArray *sortedXCTestFiles = [xcTestFiles sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        NSUInteger numTests1 = [(BPXCTestFile *)obj1 numTests];
        NSUInteger numTests2 = [(BPXCTestFile *)obj2 numTests];
        return numTests2 - numTests1;
    }];
    if (sortedXCTestFiles.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:BPErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Found no XCTest files.\n"
                                                     "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode."]}];
        }
        return NULL;
    }
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        if (![noSplit containsObject:[xctFile name]]) {
            totalTests += [xctFile numTests];
        }
    }
    NSUInteger testsPerGroup = totalTests/numBundles;
    if (testsPerGroup < 1) {
        // We are trying to pack too few tests into too many bundles
        if (error) {
            *error = [NSError errorWithDomain:BPErrorDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:
                                                        @"Trying to pack too few tests (%lu) into too many bundles (%lu).",
                                                        (unsigned long)totalTests, (unsigned long)numBundles
                                                     ]}];
        }
        return NULL;
    }
    NSMutableArray *bundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        // if the xctfile is in nosplit list, don't pack it
        if ([noSplit containsObject:[xctFile name]] || [xctFile numTests] < testsPerGroup) {
            // just pack the whole xctest file and move on
            NSRange range;
            range.location = 0;
            range.length = [xctFile numTests];

            // testsToRun doesn't work reliably, switch to use testsToSkip
            BPBundle *bundle = [[BPBundle alloc] initWithPath:xctFile.path andTestsToSkip:@[]];

            // Always insert no splited tests to the front.
            [bundles insertObject:bundle atIndex:0];
            continue;
        }

        // We don't want to pack tests from different xctest bundles so we just split
        // the current test bundle in chunks and pack those.
        NSArray *allTestCases = [xctFile allTestCases];
        NSUInteger packed = 0;
        while (packed < allTestCases.count) {
            NSRange range;
            range.location = packed;
            range.length = min(testsPerGroup, allTestCases.count - packed);
            NSMutableArray *testsToSkip = [NSMutableArray arrayWithArray:allTestCases];
            [testsToSkip removeObjectsInArray:[allTestCases subarrayWithRange:range]];
            NSArray *testsToSkipSorted = [testsToSkip sortedArrayUsingSelector:@selector(compare:)];
            [bundles addObject:[[BPBundle alloc] initWithPath:xctFile.path andTestsToSkip:testsToSkipSorted]];
            packed += range.length;
        }
        assert(packed == [xctFile numTests]);
    }
    return bundles;
}

@end
