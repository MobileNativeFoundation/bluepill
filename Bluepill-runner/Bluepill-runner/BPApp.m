//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPApp.h"
#import "BPXCTestFile.h"
#import "BPConstants.h"
#import "BPConfiguration.h"
#import "BPUtils.h"

@implementation BPApp

// This functions returns back a BPApp with an array of unit tests and an array of ui tests.
+ (instancetype)appWithConfig:(BPConfiguration *)config withError:(NSError *__autoreleasing *)error {
    BOOL isdir;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *hostAppPath = config.appBundlePath;
    if (!hostAppPath || ![fm fileExistsAtPath:hostAppPath isDirectory:&isdir] || !isdir) {
        if (error) {
            *error = BP_ERROR(@"Could not find app bundle at %@.", hostAppPath);
        }
        return nil;
    }
    BPApp *app = [[BPApp alloc] init];

    NSMutableArray *allUnitTestFiles = [NSMutableArray new];
    NSMutableArray *allUITestFiles = [NSMutableArray new];
    app.path = config.appBundlePath;

    // Handle single test bundle case.
    if (config.testBundlePath) {
        if (!config.testRunnerAppPath) {
            BPXCTestFile *testFile = [self testFileFromXCTestPath:config.testBundlePath isUITestBundle:NO withError:error];
            [allUnitTestFiles addObject:testFile];
        } else {
            NSAssert(config.testRunnerAppPath, @"with UI test bundle path specified, you have to pass in the ui test runner path");
            BPXCTestFile *testFile = [self testFileFromXCTestPath:config.testBundlePath isUITestBundle:YES withError:error];
            [allUITestFiles addObject:testFile];
        }
    } else {
        NSString *xcTestsPath = [hostAppPath stringByAppendingPathComponent:@"Plugins"];
        if (!([fm fileExistsAtPath:xcTestsPath isDirectory:&isdir]) && isdir) {
            NSLog(@"There is .xctest file under %@", xcTestsPath);
        }


        NSArray *unitTestFiles = [self testFilesFromDirectory:xcTestsPath isUITestBundle:NO withError:error];
        if (unitTestFiles) {
            [allUnitTestFiles addObjectsFromArray:unitTestFiles];
        }
        if (error) {return nil;}

        // Read ui test bundles.
        if (config.testRunnerAppPath) {
            NSString *xcTestsPath = [config.testRunnerAppPath stringByAppendingPathComponent:@"Plugins"];
            NSArray *uiTestFiles = [self testFilesFromDirectory:xcTestsPath isUITestBundle:YES withError:error];
            if (!([fm fileExistsAtPath:xcTestsPath isDirectory:&isdir]) && isdir) {
                NSLog(@"There is .xctest file under %@", xcTestsPath);
            }
            if (uiTestFiles) {
                [allUITestFiles addObjectsFromArray:uiTestFiles];
            }
        }
    }

    // Handle additional test bundles  (assumption - unit test only, TO BE FIXED)
    if (config.additionalUnitTestBundles) {
        for (NSString *testBundle in config.additionalUnitTestBundles) {
            BPXCTestFile *testFile = [self testFileFromXCTestPath:testBundle isUITestBundle:NO withError:error];
            [allUnitTestFiles addObject:testFile];
        }
    }

    if (config.additionalUITestBundles) {
        for (NSString *testBundle in config.additionalUnitTestBundles) {
            BPXCTestFile *testFile = [self testFileFromXCTestPath:testBundle isUITestBundle:NO withError:error];
            [allUnitTestFiles addObject:testFile];
        }
    }
    app.unitTestBundles = allUnitTestFiles;
    app.uiTestBundles = allUITestFiles;
    return app;
}

+ (NSArray *)testFilesFromDirectory:(NSString *)dirPath
                     isUITestBundle:(BOOL)isUITestBundle
                          withError:(NSError *__autoreleasing *)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:dirPath error:error];
    if (!allFiles && *error) {return nil;};
    NSMutableArray *xcTestFiles = [[NSMutableArray alloc] init];
    for (NSString *filename in allFiles) {
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"xctest"]) {
            NSString *testBundlePath = [dirPath stringByAppendingPathComponent:filename];
            BPXCTestFile *xcTestFile = [self testFileFromXCTestPath:testBundlePath isUITestBundle:isUITestBundle withError:error];
            if (!xcTestFile) return nil;
            [xcTestFiles addObject:xcTestFile];
        }
    }
    return xcTestFiles;
}

+ (BPXCTestFile *)testFileFromXCTestPath:(NSString *)path isUITestBundle:(BOOL)isUITestBundle withError:(NSError *__autoreleasing *)error {
    NSString *baseName = [[path lastPathComponent] stringByDeletingPathExtension];
    NSString *executablePath = [path stringByAppendingPathComponent:baseName];
    BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executablePath
                                                           isUITestFile:isUITestBundle
                                                              withError:error];
    return xcTestFile;

}

- (NSArray *)getAllTestBundles {
    NSMutableArray *allTestBundles = [NSMutableArray new];
    if (self.unitTestBundles.count > 0) {
        [allTestBundles addObjectsFromArray:self.unitTestBundles];
    }
    if (self.uiTestBundles.count > 0) {
        [allTestBundles addObjectsFromArray:self.uiTestBundles];
    }
    return allTestBundles;
}

- (NSString *)testBundlePathForName:(NSString *)name {
    for (BPXCTestFile *xcTest in self.unitTestBundles) {
        if ([xcTest.name isEqualToString:name]) {
            return xcTest.path;
        }
    }
    for (BPXCTestFile *xcTest in self.uiTestBundles) {
        if ([xcTest.name isEqualToString:name]) {
            return xcTest.path;
        }
    }
    return nil;
}

- (void)listTests {
    for (BPXCTestFile *xcTest in self.unitTestBundles) {
        printf("%s.xctest\n", [xcTest.name UTF8String]);
        [xcTest listTestClasses];
    }
    for (BPXCTestFile *xcTest in self.unitTestBundles) {
        printf("%s.xctest\n", [xcTest.name UTF8String]);
        [xcTest listTestClasses];
    }
}

@end
