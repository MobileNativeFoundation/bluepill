//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPXCTestFile.h"
#import "BPConstants.h"
#import "BPTestClass.h"
#import "BPUtils.h"

@implementation BPXCTestFile

NSString *swiftNmCmdline = @"nm -gU '%@' | cut -d' ' -f3 | xargs xcrun swift-demangle | cut -d' ' -f3 | grep -e '[\\.|_]'test";
NSString *objcNmCmdline = @"nm -U '%@' | grep ' t ' | cut -d' ' -f3,4 | cut -d'-' -f2 | cut -d'[' -f2 | cut -d']' -f1 | grep ' test'";

+ (instancetype)BPXCTestFileFromExecutable:(NSString *)path
                              isUITestFile:(BOOL)isUITestFile
                                 withError:(NSError **)error {
    BOOL isdir;

//    path = @"/Users/khu/Library/Developer/Xcode/DerivedData/voyager-aodwsnztqjhrikgifstschfgfhzf/Build/Products/Debug-iphonesimulator/LinkedIn.app/PlugIns/VoyagerFeedControlMenuTests2.xctest/VoyagerFeedControlMenuTests2";
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath: path isDirectory:&isdir] || isdir) {
        if (error) {
            *error = BP_ERROR(@"Could not find test bundle at path %@.", path);
        }
        return nil;
    }
    BPXCTestFile *xcTestFile = [[BPXCTestFile alloc] init];
    xcTestFile.name = [path lastPathComponent];
    xcTestFile.isUITestFile = isUITestFile;
    xcTestFile.path = [path stringByDeletingLastPathComponent];

    NSString *cmd = [NSString stringWithFormat:swiftNmCmdline, path];
    FILE *p = popen([cmd UTF8String], "r");
    if (!p) {
        if (error) {
            *error = BP_ERROR(@"Failed to load test %@.\nERROR: %s\n", path, strerror(errno));
        }
        return nil;
    }
    char *line = NULL;
    size_t len = 0;
    ssize_t read;
    NSMutableDictionary *testClassesDict = [[NSMutableDictionary alloc] init];
    NSMutableArray *allClasses = [[NSMutableArray alloc] init];
    while ((read = getline(&line, &len, p)) != -1) {
        NSString *testName = [[NSString stringWithUTF8String:line]
                              stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        NSArray *parts = [testName componentsSeparatedByString:@"."];
        if (parts.count != 3) {
            continue;
        }
        BPTestClass *testClass = testClassesDict[parts[1]];
        if (!testClass) {
            testClass = [[BPTestClass alloc] initWithName:parts[1]];
            testClassesDict[parts[1]] = testClass;
            [allClasses addObject:testClass];
        }
        if (![parts[2] containsString:@"DISABLE"]) {
            [testClass addTestCase:[[BPTestCase alloc] initWithName:parts[2]]];
        }
    }
    if (pclose(p) == -1) {
        if (error) {
            *error = BP_ERROR(@"Failed to execute command: %@.\nERROR: %s\n", cmd, strerror(errno));
        }
        return nil;
    }

    cmd = [NSString stringWithFormat:objcNmCmdline, path];
    NSString *output = [BPUtils runShell:cmd];
    NSArray *testsArray = [output componentsSeparatedByString:@"\n"];
    for (NSString *line in testsArray) {
        NSArray *parts = [line componentsSeparatedByString:@" "];
        if (parts.count != 2) {
            continue;
        }
        BPTestClass *testClass = testClassesDict[parts[0]];
        if (!testClass) {
            testClass = [[BPTestClass alloc] initWithName:parts[0]];
            testClassesDict[parts[0]] = testClass;
            [allClasses addObject:testClass];
        }
        [testClass addTestCase:[[BPTestCase alloc] initWithName:parts[1]]];
    }


    xcTestFile.testClasses = [NSArray arrayWithArray:allClasses];
    return xcTestFile;
}

- (void)listTestClasses {
    for (BPTestClass *testClass in self.testClasses) {
        [testClass listTestCases];
    }
}

- (NSUInteger)numTests {
    int count = 0;
    for (BPTestClass *testClass in self.testClasses) {
        count += [testClass numTests];
    }
    return count;
}

- (NSArray *)allTestCases {
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (BPTestClass *testClass in self.testClasses) {
        for (BPTestCase *testCase in testClass.testCases) {
            [ret addObject:[NSString stringWithFormat:@"%@/%@", testClass.name, testCase.name]];
        }
    }
    return ret;
}

- (NSString *)description {
    int tests = 0;
    for (BPTestClass *c in self.testClasses) {
        tests += c.numTests;
    }
    return [NSString stringWithFormat:@"%@ / %lu classes / %d tests", self.name, [self.testClasses count], tests];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, self.testClasses];
}

@end
