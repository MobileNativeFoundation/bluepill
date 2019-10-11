#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

__attribute__((constructor))
void read_it() {
    NSString *outputFilePath = [[NSProcessInfo processInfo] environment][@"_BP_TEST_LIST_FILE"] ?: @"test_list.json";
    NSString *dyldLibraryPath = [[NSProcessInfo processInfo] environment][@"DYLD_LIBRARY_PATH"];
    NSString *dyldInsertLibraries = [[NSProcessInfo processInfo] environment][@"DYLD_INSERT_LIBRARIES"];
    NSString *childDyldLibraryPath = [[NSProcessInfo processInfo] environment][@"SIMCTL_CHILD_DYLD_LIBRARY_PATH"];
    NSString *childDyldInsertLibraries = [[NSProcessInfo processInfo] environment][@"SIMCTL_CHILD_DYLD_INSERT_LIBRARIES"];
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *pluginsPath = [mainBundle builtInPlugInsPath];
    NSLog(@"RAVI: Output file path is %@", outputFilePath);
    NSLog(@"RAVI: mainBundle is %@", [mainBundle description]);
    NSLog(@"RAVI: pluginsPath is %@", pluginsPath);
    NSLog(@"RAVI: dyldLibraryPath is %@", dyldLibraryPath);
    NSLog(@"RAVI: dyldInsertLibraries is %@", dyldInsertLibraries);
    NSLog(@"RAVI: childDyldLibraryPath is %@", childDyldLibraryPath);
    NSLog(@"RAVI: childDyldInsertLibraries is %@", childDyldInsertLibraries);
    NSArray* xcTests = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginsPath error:Nil];
    NSLog(@"RAVI: Got a total of %lu xctests.", [xcTests count]);
    for (NSString *xcTestBundlePath in xcTests) {
        NSString *ext = [xcTestBundlePath pathExtension];
        if (![ext isEqual:@"xctest"]) {
            NSLog(@"Skipping %@ - %@", xcTestBundlePath, ext);
            continue;
        }
        NSString *path = [pluginsPath stringByAppendingPathComponent:xcTestBundlePath];
        NSLog(@"Loading %@", path);
        NSBundle *bundle = [NSBundle bundleWithPath:path];
        if (!bundle) {
            printf("bundle failed to load!\n");
            perror("bundle");
            return;  // exit(1);
        }
        [bundle load];
    }
    NSLog(@"Creating a default test suite with all suites of suites...");
    XCTestSuite *dtest = [XCTestSuite defaultTestSuite];
    if (!dtest) {
        printf("failed in XCTestSuite\n");
        return;  // exit(1);
    }
    NSLog(@"Found a default test suite");
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (XCTestSuite *testSuite in [dtest tests]) {
        NSLog(@"Loading xctest %@; Count = %lu", [testSuite name], [testSuite testCaseCount]);
        NSMutableArray *testList = [[NSMutableArray alloc] init];
        for (XCTestSuite *ts in [testSuite tests]) {
            NSLog(@"Loaded %@; Count = %lu", [ts name], [ts testCaseCount]);
            for (XCTest *t in [ts tests]) {
                NSLog(@"Test: %@; Count = %lu", [t name], [t testCaseCount]);
                [testList addObject:[t name]];
            }
        }
        [dict setValue:[testList componentsJoinedByString:@","] forKey:[testSuite name]];
    }
    NSLog(@"Dumping tests from %lu bundles to output file", [[dict allKeys] count]);
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *err;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&err];
        if (!json) {
            NSLog(@"ERROR: %@", [err localizedDescription]);
            return;  // exit(0);
        }
        if (![json writeToFile:outputFilePath atomically:YES]) {
            NSLog(@"Failed to dump the test list");
        } else {
            NSLog(@"Dump tests to the output file");
        }
    }
    // don't actually run the app
    return;  // exit(0);
}

//NSString *getTestName(NSString *testName) {
//    NSRange searchedRange = NSMakeRange(0, [testName length]);
//    NSString *pattern = @"(?:www\\.)?((?!-)[a-zA-Z0-9-]{2,63}(?<!-))\\.?((?:[a-zA-Z0-9]{2,})?(?:\\.[a-zA-Z0-9]{2,})?)";
//    NSError  *error = nil;
//
//    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
//    NSArray* matches = [regex matchesInString:searchedString options:0 range: searchedRange];
//    for (NSTextCheckingResult* match in matches) {
//        NSString* matchText = [searchedString substringWithRange:[match range]];
//        NSLog(@"match: %@", matchText);
//        NSRange group1 = [match rangeAtIndex:1];
//        NSRange group2 = [match rangeAtIndex:2];
//        NSLog(@"group1: %@", [searchedString substringWithRange:group1]);
//        NSLog(@"group2: %@", [searchedString substringWithRange:group2]);
//    }
//
//    return
//}
