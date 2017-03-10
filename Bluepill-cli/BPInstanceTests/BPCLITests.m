//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPConfiguration.h"
#import "BPUtils.h"
#import "BPTestHelper.h"


@interface BPCLITests : XCTestCase

@end

@implementation BPCLITests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNoSchemeinCLI {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    NSError *err;
    BOOL result;
    
    result = [config processOptionsWithError:&err];
    XCTAssert(result == FALSE);
    XCTAssert([[err localizedDescription] containsString:@"Missing required option"]);
    XCTAssert([[err localizedDescription] containsString:@"-a/--app"]);
    XCTAssert([[err localizedDescription] containsString:@"-s/--scheme-path"]);
    XCTAssert([[err localizedDescription] containsString:@"-t/--test"]);
 }

- (void)testListArguments {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    [config saveOpt:[NSNumber numberWithInt:'a'] withArg:[BPTestHelper sampleAppPath]];
    [config saveOpt:[NSNumber numberWithInt:'s'] withArg:[BPTestHelper sampleTestScheme]];
    [config saveOpt:[NSNumber numberWithInt:'t'] withArg:[BPTestHelper sampleAppBalancingTestsBundlePath]];
    [config saveOpt:[NSNumber numberWithInt:'N'] withArg:[NSString stringWithUTF8String:"foo"]];
    [config saveOpt:[NSNumber numberWithInt:'N'] withArg:[NSString stringWithUTF8String:"bar"]];
    [config saveOpt:[NSNumber numberWithInt:'N'] withArg:[NSString stringWithUTF8String:"baz"]];

    NSError *err;
    BOOL result;
    
    result = [config processOptionsWithError:&err];
    XCTAssert(result);
    NSArray *want = @[@"foo", @"bar", @"baz"];
    XCTAssert([config.noSplit isEqualToArray:want]);
}

- (void)testIgnoringAdditionalTestBundles {
    // Write a config file
    NSString *tmpConfig = [BPUtils mkstemp:@"configXXX" withError:nil];
    XCTAssert(tmpConfig);
    NSString *configContents = @"                 \
    {                                               \
    \"app\" : \"/Some/Path\",                       \
    \"scheme\" : \"/Some/Scheme\",                  \
    \"additional-unit-xctests\" : [ \"/Some/XCTest\", \"rel/path\" ] , \
    }                                               \
    ";
    NSError *err;
    if (![configContents writeToFile:tmpConfig
                          atomically:NO
                            encoding:NSUTF8StringEncoding
                               error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(FALSE);
    }
    NSError *error;
    BPConfiguration *config = [[BPConfiguration alloc] initWithConfigFile:tmpConfig
                                                               forProgram:BP_SLAVE
                                                                withError:&error];
    XCTAssert(config != nil);
    NSString *relpath = [[[NSFileManager defaultManager] currentDirectoryPath] stringByAppendingPathComponent:@"rel/path"];
    NSArray *expectedArray = @[ @"/Some/XCTest", relpath ];
    XCTAssert([config.additionalUnitTestBundles isEqualToArray:expectedArray]);
    [[NSFileManager defaultManager] removeItemAtPath:tmpConfig
                                               error:nil];
    
}

- (void)testBadConfigurationFile {
    // Write a config file
    NSString *tmpConfig = [BPUtils mkstemp:@"configXXX" withError:nil];
    XCTAssert(tmpConfig);
    NSString *configContents = @"     \
    {                                \
        \"app\" : \"/Some/Path\",    \
        \"scheme\" : [ 1.0 ],        \
        \"no-split\" : 1.0           \
    }                                \
    ";
    NSError *err;
    if (![configContents writeToFile:tmpConfig
                     atomically:NO
                       encoding:NSUTF8StringEncoding
                               error:&err]) {
        NSLog(@"%@", err);
        XCTAssert(FALSE);
    }
    // First just try passing a file that doesn't exist
    BPConfiguration *config;
    
    config = [[BPConfiguration alloc] initWithConfigFile:@"/tmp/this_file_should_not_exist" forProgram:BP_SLAVE withError:&err];
    XCTAssert(config == nil);
    XCTAssert([[err localizedDescription] isEqualToString:@"The file “this_file_should_not_exist” couldn’t be opened because there is no such file."]);
    config = [[BPConfiguration alloc] initWithConfigFile:tmpConfig forProgram:BP_SLAVE withError:&err];
    XCTAssert(config == nil);
//    NSLog(@"%@", err);
    XCTAssert([[err localizedDescription] isEqualToString:@"Expected type NSArray for key 'no-split', got __NSCFNumber. Parsing failed."]);
}

@end
