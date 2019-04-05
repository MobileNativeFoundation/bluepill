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
    NSString *path = [[NSBundle bundleForClass:[self class]] resourcePath];
    // we need to have the timestamps ordered by file name
    fixTimestamps(path);
    XCTAssert([[NSFileManager defaultManager] fileExistsAtPath:path]);
    NSString *finalReport = [path stringByAppendingPathComponent:@"TEST-FinalReport.xml"];
    NSString *failureReport = [path stringByAppendingPathComponent:@"TEST-FailureReport.xml"];
    [BPReportCollector collectReportsFromPath:path deleteCollected:YES withOutputAtDir:path];
    NSData *data = [NSData dataWithContentsOfFile:finalReport];
    NSError *error;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:&error];
    XCTAssertNil(error);
    NSArray *testsuitesNodes =  [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuites"] error:&error];
    NSXMLElement *root = testsuitesNodes[0];
    NSString *got = [[root attributeForName:@"tests"] stringValue];
    XCTAssertTrue([got isEqualToString:@"24"], @"test count is wrong, wanted 24, got %@", got);
    got = [[root attributeForName:@"errors"] stringValue];
    XCTAssertTrue([got isEqualToString:@"2"], @"error count is wrong, wanted 2, got %@", got);
    got = [[root attributeForName:@"failures"] stringValue];
    XCTAssertTrue([got isEqualToString:@"1"], @"failure count is wrong, wanted 4, got %@", got);

    // now check the failure report
    NSXMLDocument *failureDoc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:failureReport] options:0 error:nil];
    XCTAssertNotNil(failureDoc, @"Could not find the failure report");
    root = [failureDoc rootElement];
    XCTAssertTrue([@"4" isEqualToString:[[root attributeForName:@"tests"] stringValue]]);
    XCTAssertTrue([@"2" isEqualToString:[[root attributeForName:@"failures"] stringValue]]);
    XCTAssertTrue([@"2" isEqualToString:[[root attributeForName:@"errors"] stringValue]]);

    BOOL collatedReport = [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:@"1/report1.xml"]];
    XCTAssert(collatedReport == NO);
}

@end
