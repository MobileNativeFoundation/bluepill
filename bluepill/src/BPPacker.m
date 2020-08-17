//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "bp/src/BPXCTestFile.h"
#import "bp/src/BPUtils.h"
#import "BPPacker.h"

@implementation BPPacker

+ (NSArray<BPXCTestFile *> *)packTests:(NSArray<BPXCTestFile *> *)xcTestFiles
                         configuration:(BPConfiguration *)config
                              andError:(NSError **)errPtr {
    if (!config.testTimeEstimatesJsonFile) {
        return [self packTestsByCount:xcTestFiles configuration:config andError:errPtr];
    } else {
        return [self packTestsByTime:xcTestFiles configuration:config andError:errPtr];
    }
}

/*!
 * @discussion Sort .xctest bundles by test counts.
 * @param xcTestFiles An NSArray of BPXCTestFile's to pack
 * @param config The configuration file for this bluepill-runner
 * @param errPtr Error, if any
 * @return An NSMutableArray of BPXCTestFile's with the tests packed into bundles.
 */
+ (NSArray<BPXCTestFile *> *)packTestsByCount:(NSArray<BPXCTestFile *> *)xcTestFiles
                                configuration:(BPConfiguration *)config
                                     andError:(NSError **)errPtr {
    [BPUtils printInfo:INFO withString:@"Packing test bundles based on test counts."];
    NSArray *testCasesToRun = config.testCasesToRun;
    NSArray *noSplit = config.noSplit;
    NSUInteger numBundles = [config.numSims integerValue];
    NSMutableArray *filteredXcTestFiles = [NSMutableArray new];

       for (BPXCTestFile *xcFile in xcTestFiles) {
           if (config.xcTestFileToRun) {
               for(NSString *includedTestFile in config.xcTestFileToRun) {
                   if ([[xcFile name] isEqualToString:includedTestFile]) {
                       [filteredXcTestFiles addObject:xcFile];
                       break;
                   }
               }
           } else {
               [filteredXcTestFiles addObject:xcFile];
           }
       }

       if (config.xcTestFileToSkip) {
           for (BPXCTestFile *xcFile in [NSArray arrayWithArray:filteredXcTestFiles]) {
               for(NSString *excludedXcTestFile in config.xcTestFileToSkip) {
                   if ([[xcFile name] isEqualToString:excludedXcTestFile]) {
                       [filteredXcTestFiles removeObject:xcFile];
                       break;
                   }
               }
           }
       }
    
    
    NSArray *sortedXCTestFiles = [filteredXcTestFiles sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSUInteger numTests1 = [(BPXCTestFile *)obj1 numTests];
        NSUInteger numTests2 = [(BPXCTestFile *)obj2 numTests];
        return numTests2 - numTests1;
    }];
    if (sortedXCTestFiles.count == 0) {
        BP_SET_ERROR(errPtr, @"Found no XCTest files.\n"
                     "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.");
        return NULL;
    }
    NSMutableDictionary<NSString *, NSSet *> *testsToRunByFilePath = [[NSMutableDictionary alloc] init];
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
                testsToRunByFilePath[xctFile.testBundlePath] = bundleTestsToRun;
                totalTests += bundleTestsToRun.count;
            }
        }
    }

    NSUInteger testsPerGroup = MAX(1, totalTests / numBundles);
    NSMutableArray<BPXCTestFile *> *bundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in sortedXCTestFiles) {
        NSArray *bundleTestsToRun = [[testsToRunByFilePath[xctFile.testBundlePath] allObjects] sortedArrayUsingSelector:@selector(compare:)];
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

/*!
 * @discussion Ideally each test bundle should not take more than totalTime/numSims, so split bundles which take longer.
 * @param config The configuration file for this bluepill-runner
 * @param testTimes Mapping of a test name to it's estimated execution time
 * @param xcTestFiles An array of xctestfiles to pack
 * @return An array of split test bundles
 */
+ (NSArray<BPXCTestFile *> *)splitXCTestBundlesWithConfig:(BPConfiguration *)config
                                            withTestTimes:(NSDictionary<NSString *, NSNumber *> *)testTimes
                                           andXCTestFiles:(NSArray<BPXCTestFile *> *)xcTestFiles {
    NSArray *noSplit = config.noSplit;
    double totalTime = [BPUtils getTotalTimeWithConfig:config
                                             testTimes:testTimes
                                        andXCTestFiles:xcTestFiles];
    // Maximum allowed bundle time to optimize the sim track execution long pole which is maximum of all track times
    double optimalBundleTime = totalTime / [[config numSims] floatValue];
    [BPUtils printInfo:INFO withString:@"Optimal Bundle Time is around %f seconds.", optimalBundleTime];
    NSDictionary<NSString *, NSSet *> *testsToRunByFilePath = [BPUtils getTestsToRunByFilePathWithConfig:config
                                                                                          andXCTestFiles:xcTestFiles];
    NSDictionary<NSString *, NSNumber *> *testEstimatesByFilePath = [BPUtils getTestEstimatesByFilePathWithConfig:config
                                                                                                        testTimes:testTimes
                                                                                                   andXCTestFiles:xcTestFiles];

    NSMutableArray<BPXCTestFile *> *bundles = [[NSMutableArray alloc] init];
    for (BPXCTestFile *xctFile in xcTestFiles) {
        NSArray *bundleTestsToRun = [[testsToRunByFilePath[xctFile.testBundlePath] allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSNumber *estimatedBundleTime = testEstimatesByFilePath[xctFile.testBundlePath];
        // If the bundle is small enough, do not split. Also do not split if the bundle is in no_split list.
        if ([noSplit containsObject:[xctFile name]] || [estimatedBundleTime doubleValue] < optimalBundleTime) {
            BPXCTestFile *bundle = [self makeBundle:xctFile withTests:bundleTestsToRun startAt:0 numTests:[bundleTestsToRun count] estimatedTime:estimatedBundleTime];
            [bundles addObject:bundle];
            continue;
        }
        for (int i = 0; i < [bundleTestsToRun count];) {
            double splitExecTime = 0.0;
            NSUInteger startIndex = i;
            while(splitExecTime < optimalBundleTime && i < [bundleTestsToRun count]) {
                NSString *test = [bundleTestsToRun objectAtIndex:i];
                if ([testTimes objectForKey:test]) {
                    if (splitExecTime + [testTimes[test] doubleValue] <= optimalBundleTime) {
                        splitExecTime += [testTimes[test] doubleValue];
                    } else {
                        break;
                    }
                }
                i++;
            }
            // Make a bundle out of current xctFile
            BPXCTestFile *bundle = [self makeBundle:xctFile withTests:bundleTestsToRun startAt:startIndex numTests:(i-startIndex) estimatedTime:[NSNumber numberWithDouble:splitExecTime]];
            [bundles addObject:bundle];
        }
    }
    [BPUtils printInfo:INFO withString:@"Splitted %lu bundles into %lu bundles.", [xcTestFiles count], [bundles count]];

    return bundles;
}

+ (NSArray<BPXCTestFile *> *)packTestsByTime:(NSArray<BPXCTestFile *> *)xcTestFiles
                               configuration:(BPConfiguration *)config
                                    andError:(NSError **)errPtr {
    [BPUtils printInfo:INFO withString:@"Packing based on individual test execution times in file path: %@", config.testTimeEstimatesJsonFile];
    if (xcTestFiles.count == 0) {
        BP_SET_ERROR(errPtr, @"Found no XCTest files.\n"
                     "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.");
        return NULL;
    }

    // load the config file
    NSDictionary<NSString *, NSNumber *> *testTimes = [BPUtils loadSimpleJsonFile:config.testTimeEstimatesJsonFile withError:errPtr];
    if (errPtr && *errPtr) {
        [BPUtils printInfo:ERROR withString:@"%@", [*errPtr localizedDescription]];
        return NULL;
    } else if (!testTimes) {
        [BPUtils printInfo:ERROR withString:@"Invalid test execution time data"];
        return NULL;
    }

    [BPUtils printInfo:INFO withString:@"Test cases to run from the config: %lu", [config.testCasesToRun count]];

    NSArray<BPXCTestFile *> * bundles = [self splitXCTestBundlesWithConfig:config
                                                             withTestTimes:testTimes
                                                            andXCTestFiles:xcTestFiles];

    // Sort bundles by execution times from longest to shortest
    NSArray *sortedBundles = [bundles sortedArrayUsingComparator:^NSComparisonResult(id _Nonnull obj1, id _Nonnull obj2) {
        NSNumber *estimatedTime1 = [(BPXCTestFile *)obj1 estimatedExecutionTime];
        NSNumber *estimatedTime2 = [(BPXCTestFile *)obj2 estimatedExecutionTime];
        if ([estimatedTime1 doubleValue] < [estimatedTime2 doubleValue]) {
            return NSOrderedDescending;
        } else if([estimatedTime1 doubleValue] > [estimatedTime2 doubleValue]) {
            return NSOrderedAscending;
        } else {
            return NSOrderedSame;
        }
    }];
    [BPUtils printInfo:INFO withString:@"The test bundles after splitting based on time and sorting from longest to shortest are..."];
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    [fmt setPositiveFormat:@".02"];
    for (BPXCTestFile *bundle in sortedBundles) {
        [BPUtils printInfo:INFO withString:@"%@ estimated to take %@ seconds and skips %lu out of %lu tests.",
                                                     bundle.name,
                                                     [fmt stringFromNumber:bundle.estimatedExecutionTime],
                                                     (unsigned long)[bundle.skipTestIdentifiers count],
                                                     (unsigned long)[bundle.allTestCases count]];
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
    [BPUtils printInfo:INFO withString:@"%@: Including range: (%lu, %lu)", xctFile.testBundlePath, (unsigned long)range.location, (unsigned long)range.length];
    [testsToSkip removeObjectsInArray:[bundleTestsToRun subarrayWithRange:range]];
    [testsToSkip addObjectsFromArray:xctFile.skipTestIdentifiers];
    [testsToSkip sortUsingSelector:@selector(compare:)];

    BPXCTestFile *bundle = [xctFile copy];
    [bundle setSkipTestIdentifiers:testsToSkip];
    [bundle setEstimatedExecutionTime:splitExecutionTime];

    return bundle;
}

@end
