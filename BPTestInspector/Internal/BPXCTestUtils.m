//
//  BPXCTestUtils.m
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import "BPXCTestUtils.h"

#import <dlfcn.h>
#import "XCTestSuite.h"
#import "XCTestCase.h"
#import "BPLoggingUtils.h"
#import "BPTestCaseInfo+Internal.h"

@implementation BPXCTestUtils

+ (void)logAllTestsInBundleWithPath:(NSString *)bundlePath toFile:(NSString *)outputPath {
    NSArray<BPTestCaseInfo *> *testCases = [self enumerateTestCasesInBundleWithPath:bundlePath];
    // Encode the test data
    NSError *encodingError;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:testCases requiringSecureCoding:NO error:&encodingError];
    // Write to file.
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:outputPath];
//    [fileHandle writeData:data];
    [testCases.description writeToFile:outputPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [fileHandle closeFile];
    
    NSString *output = [NSString stringWithFormat:@"Wrote to file: %@.", outputPath];
    [BPLoggingUtils log:output];
}

+ (NSArray<BPTestCaseInfo *> *)enumerateTestCasesInBundleWithPath:(NSString *)bundlePath {
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
    if (!bundle || !bundle.executablePath) {
        // Log error...
        [BPLoggingUtils logError:[NSString stringWithFormat:@"Unable to get executable path from bundle: %@", bundle]];
        return @[];
    }
    return [self enumerateTestCasesInBundle:bundle];
}


//static void listBundle(NSString *testBundlePath, NSString *outputFile)
+ (NSArray<BPTestCaseInfo *> *)enumerateTestCasesInBundle:(NSBundle *)bundle {
    /**
     We need to remove the XCTest preference before continuing so that
     we can open the bundle without actually executing it. If you start
     to see logs resembling test output, it means this hasn't been done.
     
     TLDR: opening an .xctest file will normally cause the linker to load
     the XCTest framework, which will trigger `XCTestSuite.initialize`
     and start running the tests.
     */
    
//    NSLog(@"INJECTION - %@", [NSUserDefaults.standardUserDefaults objectForKey:@"XCTest"]);
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"XCTest"];
    [NSUserDefaults.standardUserDefaults synchronize];

    /**
     We must actually open the test bundle so that all of the test cases are loaded into memory.
     We use `dlopen` here instead of `NSBundle.loadAndReturnError` for more informative messages on error.
     */
    if (dlopen(bundle.executablePath.UTF8String, RTLD_LAZY) == NULL) {
        [BPLoggingUtils logError:[NSString stringWithFormat:@"Unable to open test bundle's executable path - %@", bundle.executablePath]];
        
        [BPLoggingUtils logError:@"What's the error???"];
        fprintf(stderr, "%s\n", dlerror());
        return @[];
    }

    [NSUserDefaults.standardUserDefaults setObject:@"None" forKey:@"XCTest"];

    /**
     Note that `XCTestSuite`, `XCTestCase`, etc all subclass `XCTest`, so to enumerate all tests in the current
     bundle, we'll want to start `XCTestSuite.allTests`, and expand out all nested `XCTestSuite`s, adding
     the suite's `<testSuite>.tests` to our array.
     */
    NSMutableArray<BPTestCaseInfo *> *testList = [NSMutableArray array];
    NSMutableArray<XCTest *> *queue = [@[XCTestSuite.allTests] mutableCopy];
    while (queue.count) {
        XCTest *test = queue.firstObject;
        [queue removeObjectAtIndex:0];
        // If it's another nested XCTestSuite, keep going deeper!
        // If it's an XCTestCase, we've hit a leaf and can just add it to our `testList`.
        if ([test isKindOfClass:XCTestSuite.class]) {
            XCTestSuite *testSuite = (XCTestSuite *)test;
            [queue addObjectsFromArray:testSuite.tests];
        } else if ([test isKindOfClass:XCTestCase.class]) {
            XCTestCase *testCase = (XCTestCase *)test;
            [BPLoggingUtils log:[NSString stringWithFormat:@"testCase: %@", testCase]];
            [testList addObject:[BPTestCaseInfo infoFromTestCase:testCase]];
        } else {
            [BPLoggingUtils logError:@"Found a currently unhandled XCTest type while enumerating tests"];
        }
    }
    return testList;
}

@end
