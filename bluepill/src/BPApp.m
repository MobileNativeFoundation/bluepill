//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPApp.h"
#import "bp/src/BPConstants.h"
#import "bp/src/BPConfiguration.h"
#import "bp/src/BPUtils.h"

@implementation BPApp

+ (NSArray<BPXCTestFile *>*)testsFromAppBundle:(NSString *)appBundlePath
                             andTestBundlePath:(NSString *)testBundlePath
                            andUITargetAppPath:(NSString *)UITargetAppPath
                                     withError:(NSError *__autoreleasing *)errPtr {
    if (testBundlePath == nil) {
        return [BPApp testsFromAppBundle:appBundlePath
                      andUITargetAppPath:UITargetAppPath
                               withError:errPtr];
    }
    NSMutableArray<BPXCTestFile *>* allTests = [[NSMutableArray alloc] init];
    BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:testBundlePath
                                                         andHostAppBundle:appBundlePath
                                                       andUITargetAppPath:UITargetAppPath
                                                                withError:errPtr];
    [allTests addObject:xcTestFile];
    return allTests;
}

+ (NSArray<BPXCTestFile *>*)testsFromAppBundle:(NSString *)appBundlePath
                            andUITargetAppPath:(NSString *)UITargetAppPath
                                     withError:(NSError *__autoreleasing *)errPtr {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    NSString *dirPath = [appBundlePath stringByAppendingPathComponent:@"Plugins"];
    if (![fm fileExistsAtPath:dirPath isDirectory:&isDir] || !isDir) {
        BP_SET_ERROR(errPtr, @"%s", strerror(errno));
        return nil;
    }
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:dirPath error:errPtr];
    if (!allFiles && *errPtr) {
        return nil;
    };
    NSMutableArray<BPXCTestFile *> *xcTestFiles = [[NSMutableArray alloc] init];
    for (NSString *filename in allFiles) {
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"xctest"]) {
            NSString *testBundlePath = [dirPath stringByAppendingPathComponent:filename];
            BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:testBundlePath
                                                                 andHostAppBundle:appBundlePath
                                                               andUITargetAppPath:UITargetAppPath
                                                                        withError:errPtr];
            if (!xcTestFile) return nil;
            [xcTestFiles addObject:xcTestFile];
        }
    }
    return xcTestFiles;
}

+ (NSArray <BPXCTestFile *>*)testsFromXCTestRunDict:(NSDictionary *)xcTestRunDict
                                   andXCTestRunPath:(NSString *)xcTestRunPath
                                       andXcodePath:(NSString *)xcodePath
                                          withError:(NSError *__autoreleasing *)errPtr {

    NSMutableArray<BPXCTestFile *> *allXCTestFiles = [[NSMutableArray alloc] init];
    NSUInteger errorCount = 0;
    // We are reading an XCTestRun file's dictionary and returning an Array so we sort
    // the keys to produce a deterministic list. This helps make bluepill runs reproducible.
    for (NSString *key in [xcTestRunDict.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        if ([key isEqualToString:@"__xctestrun_metadata__"]) {
            // Xcode 10.1 introduced this in the xctestrun file format.
            continue;
        }
        BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromDictionary:[xcTestRunDict objectForKey:key]
                                                               withTestRoot:[xcTestRunPath stringByDeletingLastPathComponent]
                                                               andXcodePath:xcodePath
                                                                   andError:errPtr];
        if (!xcTestFile) {
            [BPUtils printInfo:ERROR withString:@"Failed to read data for %@", key];
            errorCount++;
            continue;
        }
        [allXCTestFiles addObject:xcTestFile];
    }
    if (errorCount) {
        BP_SET_ERROR(errPtr, @"Failed to load some test bundles");
        return nil;
    }
    return allXCTestFiles;
}

+ (instancetype)appWithConfig:(BPConfiguration *)config
                    withError:(NSError *__autoreleasing *)errPtr {

    BPApp *app = [[BPApp alloc] init];
    NSMutableArray<BPXCTestFile *> *allXCTestFiles = [[NSMutableArray alloc] init];

    if (config.tests != nil && config.tests.count != 0) {
        [BPUtils printInfo:INFO withString:@"Using test bundles"];
        NSMutableArray<BPXCTestFile *> *loadedTests = [[NSMutableArray alloc] initWithCapacity:config.tests.count];
        for (NSString *testName in config.tests) {
            BPTestPlan *testPlan = [config.tests objectForKey:testName];
            BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromBPTestPlan:testPlan withName:testName andError:errPtr];
            if (*errPtr)
                return nil;
            [loadedTests addObject:xcTestFile];
        }

        app.testBundles = loadedTests;

        return app;
    }

    if (config.xcTestRunDict) {
        NSAssert(config.xcTestRunPath, @"");
        [BPUtils printInfo:INFO withString:@"Using xctestrun configuration"];
        NSArray<BPXCTestFile *> *loadedTests = [BPApp testsFromXCTestRunDict:config.xcTestRunDict
                                                            andXCTestRunPath:config.xcTestRunPath
                                                                andXcodePath:config.xcodePath
                                                                   withError:errPtr];
        if (loadedTests == nil) {
            return nil;
        }

        [allXCTestFiles addObjectsFromArray:loadedTests];
    } else if (config.appBundlePath) {
        NSAssert(config.appBundlePath, @"no app bundle and no xctestrun file");
        [BPUtils printInfo:WARNING withString:@"Using broken configuration, consider using .xctestrun files"];
        [allXCTestFiles addObjectsFromArray:[BPApp testsFromAppBundle:config.appBundlePath
                                                    andTestBundlePath:config.testBundlePath
                                                   andUITargetAppPath:config.testRunnerAppPath
                                                            withError:errPtr]];
    } else {
        BP_SET_ERROR(errPtr, @"xctestrun file must be given, see usage.");
        return nil;
    }

    if (config.additionalUnitTestBundles) {
        for (NSString *testBundle in config.additionalUnitTestBundles) {
            BPXCTestFile *testFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:testBundle
                                                               andHostAppBundle:config.appBundlePath
                                                             andUITargetAppPath:config.testRunnerAppPath
                                                                      withError:errPtr];
            [allXCTestFiles addObject:testFile];
        }
    }

    if (config.additionalUITestBundles) {
        for (NSString *testBundle in config.additionalUnitTestBundles) {
            BPXCTestFile *testFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:testBundle
                                                               andHostAppBundle:config.testRunnerAppPath
                                                                      withError:errPtr];
            [allXCTestFiles addObject:testFile];
        }
    }

    app.testBundles = allXCTestFiles;
    return app;
}

- (void)listTests {
    for (BPXCTestFile *xcTest in self.testBundles) {
        printf("%s.xctest\n", [xcTest.name UTF8String]);
        [xcTest listTestClasses];
    }
}

@end
