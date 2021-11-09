//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <XCTest/XCTest.h>
#import "bluepill/src/BPReportCollector.h"

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

void fixTimestamps(NSString *path) {
    NSURL *directoryURL = [NSURL fileURLWithPath:path isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             NSLog(@"Failed to process url %@: %@", url, [error localizedDescription]);
                                             return YES;
                                         }];
    NSMutableArray *allURLS = [[NSMutableArray alloc] init];
    for (NSURL *url in enumerator) {
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil]) {
            NSLog(@"Failed to get resource from url %@", url);
        }
        else if (![isDirectory boolValue]) {
            if ([[url pathExtension] isEqualToString:@"xml"]) {
                [allURLS addObject:url];
            }
        }
    }
    // sort the files by name
    NSMutableArray *sortedURLS;
    sortedURLS = [NSMutableArray arrayWithArray:[allURLS sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *first = [(NSURL *)a path];
        NSString *second = [(NSURL *)b path];
        return [first compare:second];
    }]];
    // finally touch them
    for (NSURL *url in sortedURLS) {
        [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate:[NSDate date]} ofItemAtPath:[url path] error:nil];
    }


}

- (void)testCollectReportsFromPath {
    NSString *fixturePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"simulator"];
    // we need to have the timestamps ordered by file name
    fixTimestamps(fixturePath);
    XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:fixturePath]);
    NSString *finalReport = [fixturePath stringByAppendingPathComponent:@"TEST-FinalReport.xml"];
    [BPReportCollector collectReportsFromPath:fixturePath deleteCollected:YES withOutputAtDir:fixturePath];
    NSData *data = [NSData dataWithContentsOfFile:finalReport];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
    XCTAssertNil(error);
    NSArray *testsuitesNodes =  [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuites"] error:&error];
    NSXMLElement *root = testsuitesNodes[0];
    NSString *got = [[root attributeForName:@"tests"] stringValue];
    NSString *want = @"26";
    XCTAssertTrue([got isEqualToString:want], @"test count is wrong, wanted %@, got %@", want, got);
    got = [[root attributeForName:@"errors"] stringValue];
    want = @"2";
    XCTAssertTrue([got isEqualToString:want], @"error count is wrong, wanted %@, got %@", want, got);
    got = [[root attributeForName:@"failures"] stringValue];
    want = @"3";
    XCTAssertTrue([got isEqualToString:want], @"failure count is wrong, wanted %@, got %@", want, got);

    // make sure the order is right
    NSArray *retriedTests = [doc nodesForXPath:@"//testcase[@name='test2' and @classname='Class1']" error:nil];
    XCTAssert(retriedTests.count == 3, @"Did not find three tries for test2");
    XCTAssert([[retriedTests[0] nodesForXPath:@"failure" error:nil] count] == 1, @"First was not a failure");
    XCTAssert([[retriedTests[1] nodesForXPath:@"failure" error:nil] count] == 1, @"Second was not a failure");
    XCTAssert([[retriedTests[2] nodesForXPath:@"failure" error:nil] count] == 0, @"Third was not a success");

    BOOL collatedReport = [[NSFileManager defaultManager] fileExistsAtPath:[fixturePath stringByAppendingPathComponent:@"1/report1.xml"]];
    XCTAssert(collatedReport == NO);
}

- (void)testCollectReportsFromPathWithInvalidXml {
    NSString *bundleRootPath = [[NSBundle bundleForClass:[self class]] resourcePath];
    NSString *fixturePath = [bundleRootPath stringByAppendingPathComponent:@"simulator-invalid-xml"];
    // we need to have the timestamps ordered by file name
    fixTimestamps(fixturePath);
    XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:fixturePath]);
    NSString *finalReport = [fixturePath stringByAppendingPathComponent:@"TEST-FinalReport.xml"];
    [BPReportCollector collectReportsFromPath:fixturePath deleteCollected:YES withOutputAtDir:fixturePath];
    NSError *error;
    NSString *collectorReportContents = [NSString stringWithContentsOfFile:finalReport encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);

    NSString *expectedReport = [bundleRootPath stringByAppendingPathComponent:@"Expected-TEST-FinalReport-for-invalid-xml.xml"];
    error = nil;
    NSString *expectedReportContents = [NSString stringWithContentsOfFile:expectedReport encoding:NSUTF8StringEncoding error:&error];
    XCTAssertNil(error);

    XCTAssertEqualObjects(collectorReportContents, expectedReportContents);
}

@end
