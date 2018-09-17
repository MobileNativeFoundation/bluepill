//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import <BluepillLib/BPConfiguration.h>
#import <BluepillLib/BPUtils.h>
#import "BPTestHelper.h"

@interface BPCLITests : XCTestCase

@end

@implementation BPCLITests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNoSchemeinCLI {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
    NSError *err;
    BOOL result;
    
    result = [config processOptionsWithError:&err];
    XCTAssert(result == FALSE);
    XCTAssert([[err localizedDescription] containsString:@"Missing required option"], @"GOT: %@", [err localizedDescription]);
    XCTAssert([[err localizedDescription] containsString:@"-a/--app"], @"GOT: %@", [err localizedDescription]);
    XCTAssert([[err localizedDescription] containsString:@"-s/--scheme-path"], "GOT: %@", [err localizedDescription]);
}

- (void)testAdditionalTestBundles {
    NSError *err;
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    config.appBundlePath = [BPTestHelper sampleAppPath];
    NSString *path = @"testScheme.xcscheme";
    [config saveOpt:[NSNumber numberWithInt:'a'] withArg:[BPTestHelper sampleAppPath]];
    [config saveOpt:[NSNumber numberWithInt:'s'] withArg:[BPTestHelper sampleTestScheme]];
    [config saveOpt:[NSNumber numberWithInt:'t'] withArg:[BPTestHelper sampleTestScheme]];
    [config saveOpt:[NSNumber numberWithInt:'X'] withArg:@"/this/is/an/invalid/path"];
    config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];

    [config saveOpt:[NSNumber numberWithInt:349] withArg:@"/tmp/extra-stuff"];

    BOOL result = [config processOptionsWithError:&err];
    XCTAssert(result == TRUE);
    XCTAssert([config.additionalUnitTestBundles isEqualToArray:@[@"/tmp/extra-stuff"]]);
}

- (void)testXcodePathIsWrong {
    NSError *err;
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_MASTER];
    [config saveOpt:[NSNumber numberWithInt:'a'] withArg:[BPTestHelper sampleAppPath]];
    [config saveOpt:[NSNumber numberWithInt:'s'] withArg:[BPTestHelper sampleTestScheme]];
    [config saveOpt:[NSNumber numberWithInt:'X'] withArg:@"/this/is/an/invalid/path"];
    
    BOOL result = [config processOptionsWithError:&err];
    XCTAssert(result == TRUE);
    
    result = [config validateConfigWithError:&err];
    XCTAssert(result == FALSE);
    XCTAssert([[err localizedDescription] isEqualToString:@"Could not find Xcode at /this/is/an/invalid/path"]);
}

@end
