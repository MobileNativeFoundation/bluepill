//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPHTMLReportWriter.h"
#import "BPReportCollector.h"
#import "bp/src/BPUtils.h"

// Save path and mtime for reports (sort by mtime)
@interface BPXMLReport:NSObject
@property(atomic, strong) NSURL *url;
@property(atomic, strong) NSDate *mtime;
@end

@implementation BPXMLReport

- (id) initWithPath:(NSURL *)url andMTime:(NSDate *)mtime {
    self = [super init];
    if (self) {
        self.url = url;
        self.mtime = mtime;
    }
    return self;
}
@end

@implementation BPReportCollector

+ (void)collectReportsFromPath:(NSString *)reportsPath
               deleteCollected:(BOOL)deleteCollected
               withOutputAtDir:(NSString *)finalReportsDir {
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSString *finalReportPath = [finalReportsDir stringByAppendingPathComponent:@"TEST-FinalReport.xml"];
    NSString *traceFilePath = [finalReportsDir stringByAppendingPathComponent:@"trace-profile.json"];

    [fileManager removeItemAtPath:finalReportPath error:nil];
    [fileManager removeItemAtPath:traceFilePath error:nil];

    NSURL *directoryURL = [NSURL fileURLWithPath:reportsPath isDirectory:YES];
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             [BPUtils printInfo:ERROR withString:@"Failed to process url %@: %@", url, [error localizedDescription]];
                                             return YES;
                                         }];
    NSMutableData *traceData = nil;
    NSMutableArray<BPXMLReport *> *reports = [[NSMutableArray alloc] init];

    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            [BPUtils printInfo:ERROR withString:@"Failed to get resource from url %@", url];
        } else if (![isDirectory boolValue]) {
            if ([[url pathExtension] isEqualToString:@"xml"]) {
                [BPUtils printInfo:DEBUGINFO withString:@"JUnit collecting: %@", [url path]];
                NSString *path = [url path];
                NSDictionary *fileAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:&error];
                if (error) {
                    [BPUtils printInfo:ERROR withString:@"Failed to get attributes for '%@': %@", path, [error localizedDescription]];
                    continue;
                }
                NSDate *mtime = [fileAttrs objectForKey:NSFileModificationDate];
                BPXMLReport *report = [[BPXMLReport alloc] initWithPath:url andMTime:mtime];
                [reports addObject:report];
                continue;
            }
            if ([[url pathExtension] isEqualToString:@"json"]) {
                [BPUtils printInfo:DEBUGINFO withString:@"Collecting trace report: %@", [url path]];
                NSData *data = [fileManager contentsAtPath:[url path]];
                if (!traceData) {
                    traceData = [[NSMutableData alloc] initWithData:[@"[\n" dataUsingEncoding:NSUTF8StringEncoding]];
                } else {
                    [traceData appendData:[@"," dataUsingEncoding:NSUTF8StringEncoding]];
                }
                [traceData appendData:data];
                if (deleteCollected) {
                    [fileManager removeItemAtURL:url error:nil];
                }
                continue;
            }
        }
    }
    if (traceData) {
        [traceData appendData:[@"]\n" dataUsingEncoding:NSUTF8StringEncoding]];
        [traceData writeToFile:traceFilePath atomically:YES];
        [BPUtils printInfo:INFO withString:@"Trace profile: %@", traceFilePath];
    }
    NSXMLDocument *jUnitReport = [self collateReports:reports
                                    andDeleteCollated:deleteCollected
                                         withOutputAt:finalReportPath];

    // write a html report
    [[BPHTMLReportWriter new] writeHTMLReportWithJUnitReport:jUnitReport
                                                    inFolder:finalReportsDir];
}

+ (NSXMLDocument *)collateReports:(NSMutableArray <BPXMLReport *> *)reports
     andDeleteCollated:(BOOL)deleteCollated
          withOutputAt:(NSString *)finalReportPath {
    NSError *err;

    // sort them by modification date, newer reports trump old reports
    NSMutableArray *sortedReports;
    sortedReports = [NSMutableArray arrayWithArray:[reports sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSDate *first = [(BPXMLReport *)a mtime];
        NSDate *second = [(BPXMLReport *)b mtime];
        return [first compare:second];
    }]];

    NSXMLDocument *targetReport = [self newEmptyXMLDocumentWithName:@"All tests"];

    for (BPXMLReport *report in sortedReports) {
        [BPUtils printInfo:DEBUGINFO withString:@"MERGING REPORT: %@", [[report url] path]];
        @autoreleasepool {
            NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithContentsOfURL:[report url] options:NSXMLDocumentTidyXML error:&err];
            if (err) {
                [BPUtils printInfo:ERROR withString:@"Failed to parse '%@': %@", [[report url] path], [err localizedDescription]];
                [BPUtils printInfo:ERROR withString:@"SOME TESTS MIGHT BE MISSING"];
                continue;
            }
            // grab all the test suites
            for (NSXMLElement *testSuite in [xmlDoc nodesForXPath:@"/testsuites/testsuite" error:nil]) {
                NSString *testSuiteName = [[testSuite attributeForName:@"name"] stringValue];
                [BPUtils printInfo:DEBUGINFO withString:@"TestSuite: %@", testSuiteName];
                NSXMLElement *targetTestSuite = [[targetReport nodesForXPath:[NSString stringWithFormat:@"//testsuite[@name='%@']", testSuiteName] error:nil] firstObject];
                if (targetTestSuite) {
                    [self collateTestSuite:testSuite into:targetTestSuite];
                } else {
                    NSXMLElement *testSuites = [[targetReport nodesForXPath:@"/testsuites" error:nil] firstObject];
                    [testSuites addChild:[testSuite copy]];
                }
            }
            // finally, delete the merged report
            if (deleteCollated) {
                [[NSFileManager defaultManager] removeItemAtURL:[report url] error:nil];
            }
        }
    }
    // update counts
    for (NSXMLElement *testSuite in [targetReport nodesForXPath:@"/testsuites/testsuite/testsuite" error:nil]) {
        [self updateTestCaseCounts:testSuite];
    }
    for (NSXMLElement *testSuite in [targetReport nodesForXPath:@"/testsuites/testsuite" error:nil]) {
        [self updateTestSuiteCounts:testSuite];
    }
    [self updateTestSuiteCounts:[[targetReport objectsForXQuery:@"//testsuites" error:nil] firstObject]];

    NSData *xmlData = [targetReport XMLDataWithOptions:NSXMLNodePrettyPrint];
    [xmlData writeToFile:finalReportPath atomically:YES];
    return targetReport;
}

+ (NSXMLDocument *)newEmptyXMLDocumentWithName:(NSString *)name {
    NSXMLElement *rootElement = [[NSXMLElement alloc] initWithName:@"testsuites"];
    [rootElement addAttribute:[NSXMLNode attributeWithName:@"name" stringValue:name]];
    [rootElement addAttribute:[NSXMLNode attributeWithName:@"tests" stringValue:@"0"]];
    [rootElement addAttribute:[NSXMLNode attributeWithName:@"failures" stringValue:@"0"]];
    [rootElement addAttribute:[NSXMLNode attributeWithName:@"errors" stringValue:@"0"]];
    [rootElement addAttribute:[NSXMLNode attributeWithName:@"time" stringValue:@"0.0"]];

    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithRootElement:rootElement];
    [doc setCharacterEncoding:@"UTF-8"];
    [doc setVersion:@"1.0"];
    [doc setStandalone:YES];
    return doc;
}

+ (void) collateTestSuite:(NSXMLElement *)testSuite into:(NSXMLElement *)targetTestSuite {
    [BPUtils printInfo:DEBUGINFO withString:@"Collating '%@' into '%@'", [[testSuite attributeForName:@"name"] stringValue], [[targetTestSuite attributeForName:@"name"] stringValue]];
    // testsuite elements must have either all testsuite children or all testcase children
    NSString *firstChild = [[[testSuite children] firstObject] name];
    if ([firstChild isEqualToString:@"testsuite"]) {
        [self collateTestSuiteTestSuites:testSuite into:targetTestSuite];
    } else if ([firstChild isEqualToString:@"testcase"]) {
        [self collateTestSuiteTestCases:testSuite into:targetTestSuite];
    } else if (firstChild) { // empty
        [BPUtils printInfo:ERROR withString:@"Unknown child node in '%@': %@", [[testSuite attributeForName:@"name"] stringValue],  firstChild];
        assert(false);
    }
}

+ (void)collateTestSuiteTestSuites:(NSXMLElement *)testSuite into:(NSXMLElement *)targetTestSuite {
    [BPUtils printInfo:DEBUGINFO withString:@"Collating TestSuites under: %@", [[testSuite attributeForName:@"name"]stringValue]];
    for (NSXMLElement *ts in [testSuite nodesForXPath:@"testsuite" error:nil]) {
        NSXMLElement *tts = [[targetTestSuite nodesForXPath:[NSString stringWithFormat:@"testsuite[@name='%@']", [[ts attributeForName:@"name"] stringValue]]
                                                      error:nil] firstObject];
        if (tts) {
            [BPUtils printInfo:DEBUGINFO withString:@"match: %@", [[tts attributeForName:@"name"] stringValue]];
            [self collateTestSuiteTestCases:ts into:tts];
        } else {
            [BPUtils printInfo:DEBUGINFO withString:@"inserting: %@", [[ts attributeForName:@"name"] stringValue]];
            [targetTestSuite addChild:[ts copy]];
        }
    }
}

+ (void)collateTestSuiteTestCases:(NSXMLElement *)testSuite into:(NSXMLElement *)targetTestSuite {
    [BPUtils printInfo:DEBUGINFO withString:@"Collating TestCases under: %@", [[testSuite attributeForName:@"name"] stringValue]];
    int testCaseCount = 0;
    for (NSXMLElement *testCase in [testSuite nodesForXPath:@"testcase" error:nil]) {
        NSString *className = [[testCase attributeForName:@"classname"] stringValue];
        NSString *name = [[testCase attributeForName:@"name"] stringValue];
        NSXMLElement *targetTestCase = [[targetTestSuite nodesForXPath:[NSString stringWithFormat:@"testcase[@name='%@' and @classname='%@']", name, className]
                                                                 error:nil] firstObject];
        NSXMLElement *parent;
        if (targetTestCase) {
            [BPUtils printInfo:DEBUGINFO withString:@"testcase match: %@", [[targetTestCase attributeForName:@"name"] stringValue]];
            parent = (NSXMLElement *)[targetTestCase parent];
            // append the latest result at the end
            NSUInteger insertIndex;
            for (insertIndex = [targetTestCase index]; insertIndex < [[parent children] count]; insertIndex++) {
                NSXMLElement *currentTestCase = (NSXMLElement *)[[parent children] objectAtIndex:insertIndex];
                NSString *thisName = [[currentTestCase attributeForName:@"name"] stringValue];
                NSString *thisClassName = [[currentTestCase attributeForName:@"classname"] stringValue];
                if ([name isNotEqualTo:thisName] || [className isNotEqualTo:thisClassName]) {
                    break;
                }
            }
            [parent insertChild:[testCase copy] atIndex:insertIndex];
        } else {
            [BPUtils printInfo:DEBUGINFO withString:@"testcase insertion: %@", [[testCase attributeForName:@"name"] stringValue]];
            [targetTestSuite addChild:[testCase copy]];
            testCaseCount++;
        }
    }
    // merge the counts
    NSXMLNode *testsAttr = [targetTestSuite attributeForName:@"tests"];
    if (testsAttr) {
        testCaseCount += [[testsAttr stringValue] intValue];
    } else {
        testsAttr = [NSXMLNode attributeWithName:@"tests" stringValue:@"0"];
        [targetTestSuite addAttribute:testsAttr];
    }
    [testsAttr setStringValue:[NSString stringWithFormat:@"%d", testCaseCount]];
}

+ (void)updateTestCaseCounts:(NSXMLElement *)testSuite {
    [BPUtils printInfo:DEBUGINFO withString:@"Updating TESTCASE counts: %@", [[testSuite attributeForName:@"name"] stringValue]];
    NSArray <NSXMLElement *>* testCases = [testSuite nodesForXPath:@"testcase" error:nil];
    [[testSuite attributeForName:@"tests"] setStringValue:[NSString stringWithFormat:@"%lu", testCases.count]];

    unsigned long failureCount = 0;
    unsigned long errorCount = 0;
    double totalTime = 0.0;
    for (NSXMLElement *testCase in testCases) {
        NSArray *failures = [testCase nodesForXPath:@"failure" error:nil];
        if ([failures count] > 0) {
            failureCount++;
        }
        NSArray *errors = [testCase nodesForXPath:@"error" error:nil];
        if ([errors count] > 0) {
            errorCount++;
        }
        totalTime += [[[testCase attributeForName:@"time"] stringValue] doubleValue];
    }
    [BPUtils printInfo:DEBUGINFO withString:@"tests: %lu, failures: %lu, errors: %lu, time: %f", testCases.count, failureCount, errorCount, totalTime];
    [[testSuite attributeForName:@"failures"] setStringValue:[NSString stringWithFormat:@"%lu", failureCount]];
    [[testSuite attributeForName:@"errors"] setStringValue:[NSString stringWithFormat:@"%lu", errorCount]];
    [[testSuite attributeForName:@"time"] setStringValue:[NSString stringWithFormat:@"%f", totalTime]];
}

+ (void)updateTestSuiteCounts:(NSXMLElement *)testSuites {
    [BPUtils printInfo:DEBUGINFO withString:@"Updating TESTSUITE counts: %@", [[testSuites attributeForName:@"name"] stringValue]];
    NSArray *allTestSuites = [testSuites nodesForXPath:@"testsuite" error:nil];
    unsigned long testCount = 0;
    unsigned long failureCount = 0;
    unsigned long errorCount = 0;
    double totalTime = 0.0;
    for (NSXMLElement *testSuite in allTestSuites) {
        testCount  += [[[testSuite attributeForName:@"tests"] stringValue] intValue];
        failureCount += [[[testSuite attributeForName:@"failures"] stringValue] intValue];
        errorCount += [[[testSuite attributeForName:@"errors"] stringValue] intValue];
        totalTime += [[[testSuite attributeForName:@"time"] stringValue] doubleValue];
    }
    [BPUtils printInfo:DEBUGINFO withString:@"tests: %lu, failures: %lu, errors: %lu, time: %f", testCount, failureCount, errorCount, totalTime];
    [[testSuites attributeForName:@"tests"] setStringValue:[NSString stringWithFormat:@"%lu", testCount]];
    [[testSuites attributeForName:@"failures"] setStringValue:[NSString stringWithFormat:@"%lu", failureCount]];
    [[testSuites attributeForName:@"errors"] setStringValue:[NSString stringWithFormat:@"%lu", errorCount]];
    [[testSuites attributeForName:@"time"] setStringValue:[NSString stringWithFormat:@"%f", totalTime]];
}

@end
