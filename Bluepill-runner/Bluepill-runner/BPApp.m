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

@implementation BPApp

+ (instancetype)BPAppWithAppBundlePath:(NSString *)path onlyTestingBundlePath:(NSString *)onlyBundlePath withExtraTestBundles:(NSArray *)extraTestBundles withError:(NSError *__autoreleasing *)error {
    BOOL isdir;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (!path || ![fm fileExistsAtPath: path isDirectory:&isdir] || !isdir) {
        if (error) {
            *error = [NSError errorWithDomain:BPErrorDomain
                                         code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     [NSString stringWithFormat:@"Could not find app bundle at %@.", path]}];
        }
        return nil;
    }
    BPApp *app = [[BPApp alloc] init];
    app.path = path;
    // read the files inside the Plugins directory
    NSString *xcTestsPath = [path stringByAppendingPathComponent:@"Plugins"];
    if (!([fm fileExistsAtPath:xcTestsPath isDirectory:&isdir]) && isdir) {
        *error = [NSError errorWithDomain:BPErrorDomain
                                     code:-1
                                 userInfo:@{NSLocalizedDescriptionKey:
                                                [NSString stringWithFormat:@"There is no 'Plugins' folder inside your app bundle at:\n"
                                                 "%@\n"
                                                 "Perhaps you forgot to 'build-for-testing'? (Cmd + Shift + U) in Xcode.\n"
                                                 "Also, if you are using XCUITest, check https://github.com/linkedin/bluepill/issues/16", path]}];
        return nil;
    }
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:xcTestsPath
                                                                        error:error];
    if (!allFiles && *error) return nil;

    NSMutableArray *xcTestFiles = [[NSMutableArray alloc] init];
    for (NSString *filename in allFiles) {
        // If `onlyBundlePath` is set and this file doesn't match, skip it
        if (onlyBundlePath && ![[onlyBundlePath lastPathComponent] isEqual:[filename lastPathComponent]]) {
            continue;
        }
        
        NSString *extension = [[filename pathExtension] lowercaseString];
        if ([extension isEqualToString:@"xctest"]) {
            NSString *bundle = [xcTestsPath stringByAppendingPathComponent:filename];
            NSString *basename = [filename stringByDeletingPathExtension];
            NSString *executable = [bundle stringByAppendingPathComponent:basename];

            BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executable
                                                                      withError:error];
            if (!xcTestFile) return nil;

            [xcTestFiles addObject:xcTestFile];
        }
    }
    for (NSString *filename in extraTestBundles) {
        NSString *basename = [[filename lastPathComponent] stringByDeletingPathExtension];
        NSString *executable = [filename stringByAppendingPathComponent:basename];

        BPXCTestFile *xcTestFile = [BPXCTestFile BPXCTestFileFromExecutable:executable
                                                                  withError:error];
        if (!xcTestFile) return nil;
        [xcTestFiles addObject:xcTestFile];
    }
    app.testBundles = [NSArray arrayWithArray:xcTestFiles];
    return app;
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
        if (verbose) {
            [testFile listTestClasses];
        }
    }
}

@end
