//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPConfiguration+Test.h"
#import "BPUtils.h"
#import "BPTestHelper.h"

@interface BPConfigurationTests : XCTestCase

@end

@implementation BPConfigurationTests

- (void)setUp {
    [super setUp];
    
    [BPUtils quietMode:[BPUtils isBuildScript]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testConfigWithNumberWhereWeExpectAString {
    BPConfiguration *config = [[BPConfiguration alloc] init];
    NSError *error;
    NSString *resourcePath = [BPTestHelper resourceFolderPath];
    NSString *configFile = [resourcePath stringByAppendingPathComponent:@"testConfig-busted.json"];
    [config loadConfigFile:configFile withError:&error];
    config.schemePath = [resourcePath stringByAppendingPathComponent:@"testScheme.xcscheme"];
    XCTAssertNil(error);
    [config validateConfigWithError:&error];
    XCTAssertNotNil(error);
    NSString *expected = [[NSString alloc] initWithFormat:@"runtime must be a string like '%s'.", BP_DEFAULT_RUNTIME];
    XCTAssert([[error localizedDescription] isEqualToString:expected], @"Wrong error message: %@", [error localizedDescription]);
}

- (void)testConfigFileLoading {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    NSError *error;
    NSString *resourcePath = [BPTestHelper resourceFolderPath];
    NSString *configFile = [resourcePath stringByAppendingPathComponent:@"testConfig.json"];
    [config loadConfigFile:configFile withError:&error];
    XCTAssertNil(error);
    XCTAssert([config.appBundlePath isEqualToString:@"/Users/khu/Library/Developer/Xcode/DerivedData/voyager-frhgmrtfxqiflycndwcgfpqkbhdy/Build/Products/Debug-iphonesimulator/LinkedIn.app"]);
    XCTAssert([config.noSplit isEqualToArray:@[@"VoyagerTests"]]);
    XCTAssertEqualObjects(config.repeatTestsCount, @1);
    XCTAssertEqualObjects(config.errorRetriesCount, @0);
    XCTAssert([config.schemePath isEqualToString:@"/Users/khu/ios/dev/voyager-ios_trunk/Voyager.xcodeproj/xcshareddata/xcschemes/VoyagerScenarioTests4.xcscheme"]);
    XCTAssertEqual(config.headlessMode, NO);
    XCTAssert([config.outputDirectory isEqualToString:@"/Users/khu/tmp/simulator"]);
}

- (void)testConfigFileWithRelativePathLoading {
    BPConfiguration *config = [[BPConfiguration alloc] initWithProgram:BP_SLAVE];
    NSError *error;
    NSString *resourcePath = [BPTestHelper resourceFolderPath];
    NSString *configFile = [resourcePath stringByAppendingPathComponent:@"testConfigRelativePath.json"];
    [config loadConfigFile:configFile withError:&error];
    XCTAssertNil(error);
    XCTAssert(![config.appBundlePath isEqualToString:@"./LinkedIn.app"]);
    XCTAssert([config.appBundlePath containsString:@"./LinkedIn.app"]);
    XCTAssert([config.noSplit isEqualToArray:@[@"VoyagerTests"]]);
    XCTAssert(![config.schemePath isEqualToString:@"./VoyagerScenarioTests4.xcscheme"]);
    XCTAssert([config.schemePath containsString:@"./VoyagerScenarioTests4.xcscheme"]);
    XCTAssert(![config.outputDirectory isEqualToString:@"./simulator"]);
    XCTAssert([config.outputDirectory containsString:@"./simulator"]);
}

@end
