//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPPacker.h"
#import <BluepillLib/BPConstants.h>
#import <BluepillLib/BPXCTestFile.h>
#import <BluepillLib/BPUtils.h>

@implementation BPPacker

+ (NSMutableArray<BPXCTestFile *> *)packTests:(NSArray<BPXCTestFile *> *)xcTestFiles
                                configuration:(BPConfiguration *)config
                                     andError:(NSError **)errPtr {
    if (!config.testTimeEstimatesJsonFile) {
        return [self packTestsByCount:xcTestFiles configuration:config andError:errPtr];
    } else {
        return [self packTestsByTime:xcTestFiles configuration:config andError:errPtr];
    }
}

+ (NSMutableArray<BPXCTestFile *> *)packTestsByCount:(NSArray<BPXCTestFile *> *)xcTestFiles
                                       configuration:(BPConfiguration *)config
                                            andError:(NSError **)errPtr {
    [BPUtils printInfo:INFO withString:@"Packing test bundles based on test counts."];
    NSArray *testCasesToRun = config.testCasesToRun;
    NSArray *noSplit = config.noSplit;
    NSArray *sortedXCTestFiles = [xcTestFiles sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSUInteger numTests1 = [(BPXCTestFile *)obj1 numTests];
        NSUInteger numTests2 = [(BPXCTestFile *)obj2 numTests];
        return numTests2 - numTests1;
    }];
    if (sortedXCTestFiles.count == 0) {
        BP_SET_ERROR(errPtr, @"Found no XCTest files.\n"
                     "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.");
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
                testsToRunByTestFilePath[xctFile.testBundlePath] = bundleTestsToRun;
                totalTests += bundleTestsToRun.count;
            }
        }
    }
    NSUInteger testsPerGroup = MAX(1, totalTests / [config.numSims integerValue]);
    NSMutableArray<BPXCTestFile *> *bundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        NSArray *bundleTestsToRun = [[testsToRunByTestFilePath[xctFile.testBundlePath] allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger bundleTestsToRunCount = [bundleTestsToRun count];
        // if the xctfile is in nosplit list, don't pack it
        if ([noSplit containsObject:[xctFile name]] || (bundleTestsToRunCount <= testsPerGroup && bundleTestsToRunCount > 0)) {
            // just pack the whole xctest file and move on
            // testsToRun doesn't work reliably, switch to use testsToSkip
            // add testsToSkip from Bluepill runner's config
            BPXCTestFile *bundle = [xctFile copy];
            bundle.skipTestIdentifiers = config.testCasesToSkip;

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
            [testsToSkip addObjectsFromArray:xctFile.skipTestIdentifiers];
            [testsToSkip sortUsingSelector:@selector(compare:)];
            BPXCTestFile *bundle = [xctFile copy];
            bundle.skipTestIdentifiers = testsToSkip;
            [bundles addObject:bundle];
            packed += range.length;
        }
        assert(packed == [bundleTestsToRun count]);
    }
    return bundles;
}

+ (NSMutableArray<BPXCTestFile *> *)packTestsByTime:(NSArray<BPXCTestFile *> *)xcTestFiles
                                      configuration:(BPConfiguration *)config
                                           andError:(NSError **)errPtr {
    [BPUtils printInfo:INFO withString:@"Packing based on individual test execution times in file path: %@", config.testTimeEstimatesJsonFile];
    if (xcTestFiles.count == 0) {
        BP_SET_ERROR(errPtr, @"Found no XCTest files.\n"
                     "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.");
        return NULL;
    }

    // load the config file
    NSDictionary *testTimes = [BPUtils loadJsonMappingFile:config.testTimeEstimatesJsonFile withError:errPtr];
    if ((errPtr && *errPtr) || !testTimes) {
        [BPUtils printInfo:ERROR withString:@"%@", [*errPtr localizedDescription]];
        return NULL;
    }

    NSMutableDictionary *testsToRunByTestFilePath = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *testEstimatedTimesByTestFilePath = [[NSMutableDictionary alloc] init];
    NSArray *testCasesToRun = config.testCasesToRun;
    [BPUtils printInfo:INFO withString:@"Test cases to run from the config: %lu", [config.testCasesToRun count]];
    double totalTime = 0.0;
    for (BPXCTestFile *xctFile in xcTestFiles) {
        NSMutableSet *bundleTestsToRun = [[NSMutableSet alloc] initWithArray:[xctFile allTestCases]];
        if (testCasesToRun) {
            [bundleTestsToRun intersectSet:[[NSSet alloc] initWithArray:testCasesToRun]];
        }
        if (config.testCasesToSkip && [config.testCasesToSkip count] > 0) {
            [bundleTestsToRun minusSet:[[NSSet alloc] initWithArray:config.testCasesToSkip]];
        }
        [BPUtils printInfo:INFO withString:@"Bundle: %@; All Tests count: %lu; bundleTestsToRun count: %lu; Tests: %@", xctFile.testBundlePath, (unsigned long)[xctFile.allTestCases count], (unsigned long)[bundleTestsToRun count], [xctFile allTestCases]];
        if ([bundleTestsToRun count] != [[xctFile allTestCases] count]) {
            NSMutableArray *allTests = [NSMutableArray arrayWithArray:[xctFile allTestCases]];
            [BPUtils printInfo:INFO withString:@"All tests: %@", [allTests componentsJoinedByString:@","]];
            [BPUtils printInfo:INFO withString:@"Bundle tests: %@", [[bundleTestsToRun allObjects] componentsJoinedByString:@","]];
            [allTests removeObjectsInArray:[bundleTestsToRun allObjects]];
            [BPUtils printInfo:INFO withString:@"Remaining tests that are not set to run: %@", [allTests componentsJoinedByString:@","]];
        }
        if (bundleTestsToRun.count > 0) {
            testsToRunByTestFilePath[xctFile.testBundlePath] = bundleTestsToRun;
            double __block testBundleExecutionTime = 0.0;
            [bundleTestsToRun enumerateObjectsUsingBlock:^(id _Nonnull test, BOOL * _Nonnull stop) {
                // TODO: Assign a sensible default if the estimate is not given
                if ([testTimes objectForKey:test]) {
                    testBundleExecutionTime += [[testTimes objectForKey:test] doubleValue];
                } else {
                    [BPUtils printInfo:INFO withString:@"Estimate not available for %@", test];
                }
            }];
            testEstimatedTimesByTestFilePath[xctFile.testBundlePath] = [NSNumber numberWithDouble:testBundleExecutionTime];
            totalTime += testBundleExecutionTime;
        }
    }
    assert([testEstimatedTimesByTestFilePath count] == [xcTestFiles count]);

    [BPUtils printInfo:INFO withString:@"Stats before splitting..."];
    NSMutableDictionary *inputDic = [NSMutableDictionary dictionary];
    for(id key in testEstimatedTimesByTestFilePath) {
        inputDic[[key substringFromIndex:[(NSString *)key rangeOfString:@"/" options:NSBackwardsSearch].location+1]] = [testEstimatedTimesByTestFilePath objectForKey:key];
        NSLog(@"%@ = %@", [key substringFromIndex:[(NSString *)key rangeOfString:@"/" options:NSBackwardsSearch].location+1], [testEstimatedTimesByTestFilePath objectForKey:key]);
    }

    int minimumBundleTime = 180;
    NSUInteger maxBundleTime = MAX(minimumBundleTime, totalTime / [config.numSims integerValue]);
    [BPUtils printInfo:INFO withString:@"Max Bundle Time is around %lu seconds.", maxBundleTime];

    // TODO: First of all check if the bundles need to be split or not (Hint: Based on numSims, current test bundle count and standard deviation of their execution times)
    NSMutableArray<BPXCTestFile *> *testBundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in xcTestFiles) {
        NSArray *bundleTestsToRun = [[testsToRunByTestFilePath[xctFile.testBundlePath] allObjects] sortedArrayUsingSelector:@selector(compare:)];
        double bundleEstimate = [testEstimatedTimesByTestFilePath[xctFile.testBundlePath] doubleValue];
        if (bundleEstimate > maxBundleTime) {
            NSUInteger packed = 0;
            double splitExecTime = 0.0;
            double sumOfSplits = 0.0;
            for (int i = 0; i < [bundleTestsToRun count];) {
                NSString *test = [bundleTestsToRun objectAtIndex:i];
                NSMutableArray *myArray = [NSMutableArray array];
                if ([testTimes objectForKey:test]) {
                    splitExecTime += [testTimes[test] doubleValue];
                    [myArray addObject:[NSNumber numberWithDouble:[testTimes[test] doubleValue]]];
                }
                i++;
                if (splitExecTime > maxBundleTime || i >= [bundleTestsToRun count]) {
                    // Make a bundle out of current xctFile
                    BPXCTestFile *bundle = [self makeBundle:xctFile
                                                  withTests:bundleTestsToRun
                                                    startAt:packed
                                                   numTests:(i-packed)
                                              estimatedTime:[NSNumber numberWithDouble:splitExecTime]];
                    [testBundles addObject:bundle];
                    packed = i;
                    sumOfSplits += splitExecTime;
                    splitExecTime = 0.0;
                }
            }
            [BPUtils printInfo:INFO
                    withString:@"Bundle execution time is %@ vs sum of splits is %f.", testEstimatedTimesByTestFilePath[xctFile.testBundlePath], sumOfSplits];
        } else {
            // just pack the whole xctest file and move on
            // testsToRun doesn't work reliably, switch to use testsToSkip
            // add testsToSkip from Bluepill runner's config
            BPXCTestFile *bundle = [self makeBundle:xctFile withTests:bundleTestsToRun startAt:0 numTests:[bundleTestsToRun count] estimatedTime:testEstimatedTimesByTestFilePath[xctFile.testBundlePath]];
            [testBundles addObject:bundle];
        }
    }
    [BPUtils printInfo:INFO withString:@"Splitted %lu bundles into %lu bundles.", [xcTestFiles count], [testBundles count]] ;

    // Sort bundles by execution times from longest to shortest
    NSMutableArray *sortedBundles = [NSMutableArray arrayWithArray:[testBundles sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSNumber *estimatedTime1 = [(BPXCTestFile *)obj1 estimatedExecutionTime];
        NSNumber *estimatedTime2 = [(BPXCTestFile *)obj2 estimatedExecutionTime];
        if ([estimatedTime1 doubleValue] < [estimatedTime2 doubleValue]) {
            return NSOrderedDescending;
        } else if([estimatedTime1 doubleValue] > [estimatedTime2 doubleValue]) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }]];
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    [fmt setPositiveFormat:@".02"];
    int bpNum = 0;
    for (BPXCTestFile *bundle in sortedBundles) {
        [BPUtils printInfo:INFO withString:@"[BP-%d] %@ estimated to take %@ seconds and skips %lu out of %lu tests.", ++bpNum, bundle.name, [fmt stringFromNumber:bundle.estimatedExecutionTime], (unsigned long)[bundle.skipTestIdentifiers count], (unsigned long)[bundle.allTestCases count]];
    }
    return sortedBundles;
}

+ (BPXCTestFile *)makeBundle:(BPXCTestFile *)xctFile
                   withTests:(NSArray *)bundleTestsToRun
                     startAt:(NSUInteger)location
                    numTests:(NSUInteger)length
               estimatedTime:(NSNumber *)splitExecutionTime {
    NSMutableArray *testsToSkip = [NSMutableArray arrayWithArray:bundleTestsToRun];
    NSRange range = NSMakeRange(location, length);
    [BPUtils printInfo:INFO withString:@"%@: Including range: (%lu, %lu); Tests: %@", xctFile.testBundlePath, (unsigned long)range.location, (unsigned long)range.length, [bundleTestsToRun subarrayWithRange:range]];
    [testsToSkip removeObjectsInArray:[bundleTestsToRun subarrayWithRange:range]];
    [testsToSkip addObjectsFromArray:xctFile.skipTestIdentifiers];
    [testsToSkip sortUsingSelector:@selector(compare:)];

    BPXCTestFile *bundle = [xctFile copy];
    [bundle setSkipTestIdentifiers:testsToSkip];
    [bundle setEstimatedExecutionTime:splitExecutionTime];

    return bundle;
}

@end
