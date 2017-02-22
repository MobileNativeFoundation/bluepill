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

@implementation BPApp

+ (instancetype)appWithConfig:(BPConfiguration *)config withError:(NSError *__autoreleasing *)error {
    BOOL isdir;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *hostAppPath = config.appBundlePath;
    if (!hostAppPath || ![fm fileExistsAtPath:hostAppPath isDirectory:&isdir] || !isdir) {
        if (error) {
            *error = [NSError errorWithDomain:BPErrorDomain
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     [NSString stringWithFormat:@"Could not find app bundle at %@.", hostAppPath]}];
        }
        return nil;
    }
    BPApp *app = [[BPApp alloc] init];

    NSMutableArray *allTestFiles = [NSMutableArray new];

    // Handle single testBundlePath (assumption - unit test only, TO BE FIXED)
    if (config.testBundlePath) {
        BPXCTestFile *testFile = [self testFileFromXCTestPath:config.testBundlePath isUITestBundle:NO withError:error];
        [allTestFiles addObject:testFile];
    } else {
        NSString *xcTestsPath = [hostAppPath stringByAppendingPathComponent:@"Plugins"];
        if (!([fm fileExistsAtPath:xcTestsPath isDirectory:&isdir]) && isdir) {
            NSLog(@"There is .xctest file under %@", xcTestsPath);
        }


        NSArray *unitTestFiles = [self testFilesFromDirectory:xcTestsPath isUITestBundle:NO withError:error];
        if (unitTestFiles) {
            [allTestFiles addObjectsFromArray:unitTestFiles];
        }
        if (error) {return nil;}
        if (config.testRunnerAppPath) {
            NSString *xcTestsPath = [hostAppPath stringByAppendingPathComponent:@"Plugins"];
            NSArray *uiTestFiles = [self testFilesFromDirectory:xcTestsPath isUITestBundle:YES withError:error];
            if (!([fm fileExistsAtPath:xcTestsPath isDirectory:&isdir]) && isdir) {
                NSLog(@"There is .xctest file under %@", xcTestsPath);
            }
            if (uiTestFiles) {
                [allTestFiles addObjectsFromArray:uiTestFiles];
            }

        }
    }

    // Handle additional test bundles  (assumption - unit test only, TO BE FIXED)
    if (config.additionalTestBundles) {
        for (NSString *testBundle in config.additionalTestBundles) {
            BPXCTestFile *testFile = [self testFileFromXCTestPath:testBundle isUITestBundle:NO withError:error];
            [allTestFiles addObject:testFile];
        }
    }
    app.testBundles = allTestFiles;
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
    NSString *baseName = [path stringByDeletingPathExtension];
    NSString *executablePath = [path stringByAppendingPathComponent:baseName];
    BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executablePath
                                                           isUITestFile:isUITestBundle
                                                              withError:error];
    return xcTestFile;

}

- (NSString *)testBundlePathForName:(NSString *)name {
    for (BPXCTestFile *xcTest in self.testBundles) {
        if ([xcTest.name isEqualToString:name]) {
            return xcTest.path;
        }
    }
    return nil;
}

- (void)listBundles:(BOOL) verbose {
    for (BPXCTestFile *testFile in self.testBundles) {
        printf("%s.xctest\n", [testFile.name UTF8String]);
        if (verbose) [testFile listTestClasses];
    }
}

@end
