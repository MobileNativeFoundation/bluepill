//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "BPReportCollector.h"

@interface BPReportCollectorTests : XCTestCase

@end

@implementation BPReportCollectorTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testCollectReportsFromPath {
    NSString *path = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *outputPath = [path stringByAppendingPathComponent:@"result.xml"];
    [BPReportCollector collectReportsFromPath:path onReportCollected:^(NSURL *fileUrl) {
        NSError *error;
        NSFileManager *fm = [NSFileManager new];
        [fm removeItemAtURL:fileUrl error:&error];
        XCTAssertNil(error);
    }  outputAtPath:outputPath];
    NSData *data = [NSData dataWithContentsOfFile:outputPath];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
    XCTAssertNil(error);
    NSArray *testsuitesNodes =  [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuites"] error:&error];
    NSXMLElement *root = testsuitesNodes[0];
    XCTAssertTrue([[[root attributeForName:@"tests"] stringValue] isEqualToString:@"271"], @"test count is wrong");
    XCTAssertTrue([[[root attributeForName:@"errors"] stringValue] isEqualToString:@"2"], @"test count is wrong");
    XCTAssertTrue([[[root attributeForName:@"failures"] stringValue] isEqualToString:@"4"], @"test count is wrong");

    NSLog(@"%@, %@, %@", [[root attributeForName:@"tests"] stringValue], [[root attributeForName:@"errors"] stringValue], [[root attributeForName:@"failures"] stringValue]);
    NSFileManager *fm = [NSFileManager new];
    [fm removeItemAtPath:outputPath error:&error];
    XCTAssertNil(error);
}
@end
