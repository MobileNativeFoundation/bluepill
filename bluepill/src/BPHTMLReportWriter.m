//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPTestReportHTML.h"
#import "bp/src/BPUtils.h"

#import "BPHTMLReportWriter.h"

static const NSString * const kHTMLPath = @"0-test-report.html";
static const NSString * const kJSPath = @"test-report.js";
static const NSString * const kFailureLogsPath = @"failure-logs";

@implementation BPHTMLReportWriter

- (NSDictionary<NSString*, NSString*> *)metaForFileWrites:(NSXMLDocument *)jUnitReport
                                                 inFolder:(nonnull NSString *)folderPath {
    NSMutableDictionary *metaData = [[NSMutableDictionary alloc] init];
    NSString *htmlPath = [folderPath stringByAppendingPathComponent:[kHTMLPath copy]];
    NSString *jsPath = [folderPath stringByAppendingPathComponent:[kJSPath copy]];
    NSString *failureLogsPath = [folderPath stringByAppendingPathComponent:[kFailureLogsPath copy]];
    // HTML data
    metaData[htmlPath] = kHTMLContent;
    [BPUtils printInfo:INFO withString:@"HTML report: %@", htmlPath];

    // write the JS goes with the html
    if (jUnitReport.childCount == 0) {
        [BPUtils printInfo:WARNING withString:@"Bluepill JUnit report has no data."];
        return nil;
    }
    NSMutableArray<NSString *> *jsLines = [[NSMutableArray alloc] initWithArray:@[
                                                                                  @"var json = {",
                                                                                  @"\t\"product\": \"All Tests\",\n",
                                                                                  @"\t\"testSuites\": [",
                                                                                  @"\t\t{",
                                                                                  @"\t\t\t\"testCases\": ["
                                                                                  ]];
    // testsuites
    // <testsuites name="AllTestUnits" tests="17" failures="0" errors="1" time="53.990912">
    NSXMLNode *rootNode = jUnitReport.children[0];
    for (NSXMLNode *testSuiteNode in rootNode.children) {
        if (testSuiteNode.kind == NSXMLElementKind && [testSuiteNode.name isEqualToString:@"testsuite"]) {
            // testsuite
            // <testsuite tests="17" failures="0" errors="1" time="53.990912" timestamp="2016-02-25T10:52:05GMT-08:00" name="Toplevel Test Suite">
            for (NSXMLNode *testClassNode in testSuiteNode.children) {
                for (NSXMLNode *testCaseNode in testClassNode.children) {
                    if (testCaseNode.kind == NSXMLElementKind && [testCaseNode.name isEqualToString:@"testcase"]) {
                        // testcase
                        // product-dashboard <testcase classname="FeedChannelUpdateTest" name="testChannelUpdateInMiniFeed" time="20.197627">
                        BOOL rc = YES;
                        NSXMLElement *testCaseElement = (NSXMLElement *)testCaseNode;
                        NSMutableArray<NSDictionary *> *errors = [[NSMutableArray alloc] init];
                        NSMutableArray<NSString *> *logs = [[NSMutableArray alloc] init];
                        for (NSXMLNode *node in testCaseNode.children) {
                            if (node.kind != NSXMLElementKind) {
                                [BPUtils printInfo:WARNING withString:@"Invalid node type: %@ is not an XMLElement", node.name];
                            }
                            NSXMLElement *element = (NSXMLElement *)node;
                            if ([node.name isEqualToString:@"failure"] || [node.name isEqualToString:@"error"]) {
                                rc = NO;
                                NSDictionary *error = @{
                                                        @"message": [[element attributeForName:@"message"] stringValue],
                                                        @"location": element.children.firstObject.stringValue
                                                        };
                                [errors addObject:error];
                            } else if ([node.name isEqualToString:@"system-out"]) {
                                // report system-out for failures only
                                [logs addObject:node.children.firstObject.stringValue];
                            }
                        }
                        NSString *className = [[testCaseElement attributeForName:@"classname"] stringValue];
                        NSString *caseName = [[testCaseElement attributeForName:@"name"] stringValue];
                        [jsLines addObject:@"\t\t\t\t{"];
                        [jsLines addObject:[NSString stringWithFormat:@"\t\t\t\t\t\"className\": \"%@\",", className]];
                        [jsLines addObject:[NSString stringWithFormat:@"\t\t\t\t\t\"name\": \"%@\",", caseName]];
                        if (!rc) {
                            [jsLines addObject:@"\t\t\t\t\t\"failed\": true,"];
                            NSMutableArray *errorMessages = [[NSMutableArray alloc] init];
                            for (NSDictionary *errorDict in errors) {
                                NSString *errorMessage = [NSString stringWithFormat:@"\"message\": \"%@\", \"location\": \"%@\"",
                                                          [self escapeStringForJS:errorDict[@"message"]],
                                                          [self escapeStringForJS:errorDict[@"location"]]];
                                [errorMessages addObject:errorMessage];
                            }
                            [jsLines addObject:[NSString stringWithFormat:@"\t\t\t\t\t\"errors\": [{%@}],",
                                                [errorMessages componentsJoinedByString:@"},{"]]];
                            NSMutableArray<NSString *> *artifacts = [[NSMutableArray alloc] init];
                            for (NSString *log in logs) {
                                NSString *logName = [NSString stringWithFormat:@"%@.%@.txt", className, caseName];
                                NSString *logPath = [failureLogsPath stringByAppendingPathComponent:logName];
                                metaData[logPath] = log;
                                NSString *relativePath = [NSString stringWithFormat:@"%@/%@", kFailureLogsPath, logName];
                                [artifacts addObject:relativePath];
                            }
                            if ([artifacts count] > 0) {
                                [jsLines addObject:[NSString stringWithFormat:@"\t\t\t\t\t\"artifacts\": [\"%@\"],\n",
                                                    [artifacts componentsJoinedByString:@"\",\""]]];
                            }
                        }
                        NSString *caseTime = [[testCaseElement attributeForName:@"time"] stringValue];
                        [jsLines addObject:[NSString stringWithFormat:@"\t\t\t\t\t\"time\": %.3f", [caseTime floatValue]]];
                        [jsLines addObject:@"\t\t\t\t},"];
                    }
                }
            }
        }
    }
    if(rootNode.kind != NSXMLElementKind) {
        [BPUtils printInfo:WARNING withString:@"Bluepill JUnit report has no data."];
    }
    NSXMLElement *rootElement = (NSXMLElement *)rootNode;
    NSString *numFailures = [[rootElement attributeForName:@"failures"] stringValue];
    NSString *numTests = [[rootElement attributeForName:@"tests"] stringValue];
    float time = [[[rootElement attributeForName:@"time"] stringValue] floatValue];
    [jsLines addObjectsFromArray:@[
                                   @"\t\t\t],",
                                   @"\t\t\t\"name\": \"All Tests\",",
                                   [NSString stringWithFormat:@"\t\t\t\"numFailures\": %@,", numFailures],
                                   [NSString stringWithFormat:@"\t\t\t\"numTests\": %@,", numTests],
                                   [NSString stringWithFormat:@"\t\t\t\"time\": %.3f,", time],
                                   @"\t\t},",
                                   @"\t],"
                                   ]];
    if ([numFailures integerValue] > 0) {
        [jsLines addObject:@"\t\"failed\": true,"];
    }
    [jsLines addObject:@"}\n"];
    metaData[jsPath] = [jsLines componentsJoinedByString:@"\n"];
    return metaData;
}


- (void)writeHTMLReportWithJUnitReport:(NSXMLDocument *)jUnitReport
                              inFolder:(nonnull NSString *)folderPath {
    NSDictionary<NSString*, NSString*> *metaData = [self metaForFileWrites:jUnitReport inFolder:folderPath];
    NSString *failureLogsPath = [folderPath stringByAppendingPathComponent:[kFailureLogsPath copy]];
    // create failure logs folder
    [[NSFileManager defaultManager] createDirectoryAtPath:failureLogsPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    for (NSString *key in metaData.allKeys) {
        [[metaData[key] dataUsingEncoding:NSUTF8StringEncoding] writeToFile:key atomically:YES];
    }
}

- (NSString *)escapeStringForJS:(NSString *)jsCode {
    NSString *ret = [jsCode stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    ret = [ret stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    ret = [ret stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    return ret;
}

@end
