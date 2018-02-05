//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPReportCollector.h"
#import "BPUtils.h"

@implementation BPReportCollector

+ (void)collectReportsFromPath:(NSString *)reportsPath
             onReportCollected:(void (^)(NSURL *fileUrl))fileHandler
                  outputAtPath:(NSString *)finalReportPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSURL *directoryURL = [NSURL fileURLWithPath:reportsPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             fprintf(stderr, "Failed to process url %s", [[url absoluteString] UTF8String]);
                                             return YES;
                                         }];

    NSMutableArray *nodesArray = [NSMutableArray new];
    NSMutableDictionary *testStats = [NSMutableDictionary new];
    int totalTests = 0;
    int totalErrors = 0;
    int totalFailures = 0;
    double totalTime = 0;

    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            fprintf(stderr, "Failed to get resource from url %s", [[url absoluteString] UTF8String]);
        }
        else if (![isDirectory boolValue]) {
            if ([[url pathExtension] isEqualToString:@"xml"]) {
                NSError *error;
                NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:url options:0 error:&error];
                if (error) {
                    [BPUtils printInfo:ERROR withString:@"Failed to parse %@: %@", url, error.localizedDescription];
                    return;
                }

                // Don't withhold the parent object.
                @autoreleasepool {
                    NSArray *testsuitesNodes =  [doc nodesForXPath:[NSString stringWithFormat:@".//%@", @"testsuites"] error:&error];
                    for (NSXMLElement *element in testsuitesNodes) {
                        totalTests += [[[element attributeForName:@"tests"] stringValue] integerValue];
                        totalErrors += [[[element attributeForName:@"errors"] stringValue] integerValue];
                        totalFailures += [[[element attributeForName:@"failures"] stringValue] integerValue];
                        totalTime += [[[element attributeForName:@"time"] stringValue] doubleValue];
                    }
                }

                NSArray *testsuiteNodes =
                [doc nodesForXPath:[NSString stringWithFormat:@".//%@/testsuite", @"testsuites"] error:&error];

                [nodesArray addObjectsFromArray:testsuiteNodes];
                if (fileHandler) {
                    fileHandler(url);
                }
            }
        }
    }

    testStats[@"name"] = @"Selected tests";
    testStats[@"tests"] = [@(totalTests) stringValue];
    testStats[@"errors"] = [@(totalErrors) stringValue];
    testStats[@"failures"] = [@(totalFailures) stringValue];
    testStats[@"time"] = [@(totalTime) stringValue];
    NSXMLElement *rootTestSuites = [[NSXMLElement alloc] initWithName:@"testsuites"];
    [rootTestSuites setAttributesWithDictionary:testStats];
    [rootTestSuites setChildren:nodesArray];
    NSXMLDocument *xmlRequest = [NSXMLDocument documentWithRootElement:rootTestSuites];
    NSData *xmlData = [xmlRequest XMLDataWithOptions:NSXMLDocumentIncludeContentTypeDeclaration];
    [xmlData writeToFile:finalReportPath atomically:YES];
}

+ (void)collectCSVFromPath:(NSString *)reportsPath
             onReportCollected:(void (^)(NSURL *fileUrl))fileHandler
                  outputAtPath:(NSString *)finalReportPath {
    
    NSMutableString *csvString = [[NSMutableString alloc] initWithCapacity:0];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:reportsPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             fprintf(stderr, "Failed to process url %s", [[url absoluteString] UTF8String]);
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            fprintf(stderr, "Failed to get resource from url %s", [[url absoluteString] UTF8String]);
        }
        else if (![isDirectory boolValue]) {
            if ([[url pathExtension] isEqualToString:@"csv"]) {
                
                NSString* filePath = [url.absoluteString stringByDeletingLastPathComponent];
                NSString* bpNum = [filePath lastPathComponent];
                NSString* fileContents = [NSString stringWithContentsOfURL:url encoding:NSASCIIStringEncoding error:nil];
                NSArray* rows = [fileContents componentsSeparatedByString:@"\n"];
                // add header
                if ([csvString length] == 0) {
                    [csvString appendString:[NSString stringWithFormat:@"bp Number,%@",[rows objectAtIndex:0]]];
                }
                for (int row = 1; row < [rows count]; row++) {
                    [csvString appendString:@"\n"];
                    [csvString appendString:[NSString stringWithFormat:@"%@,%@", bpNum, [rows objectAtIndex:row]]];
                }
            }
        }
    }
    [csvString writeToFile:finalReportPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


@end
