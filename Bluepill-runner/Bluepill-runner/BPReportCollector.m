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

    /**from here we need to go inside this node and get its child nodes
     *
     *   testsuites from a simulator report (.xml) - needs to be combined
     *    |--testsuite with scheme name (.xctest) - needs to be combined
     *           |--testsuite with test class name (XXXXTests) - needs to be combined
     *           |      |--testcase
     *           |      |--testcase
     *           |      |--testcase
     *           |           ...
     *           |--testsuite
     *                ...
     */
    
    NSXMLElement *rootElement;
    
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
                
                rootElement = rootElement == nil? doc.rootElement : [self mergeElement:rootElement withElement:doc.rootElement];

                if (fileHandler) {
                    fileHandler(url);
                }
            }
        }
    }
    
    NSXMLDocument *xmlRequest = [NSXMLDocument documentWithRootElement:rootElement];
    NSData *xmlData = [xmlRequest XMLDataWithOptions:NSXMLDocumentIncludeContentTypeDeclaration];
    [xmlData writeToFile:finalReportPath atomically:YES];
}

+ (NSXMLElement *)mergeElement:(NSXMLElement *)mainElement withElement:(NSXMLElement *)secondElement {
    
    @autoreleasepool {
        NSMutableDictionary *m_attributes = [NSMutableDictionary new];
        
        //if they have the same name, we need to combine these two elements
        if ([[[mainElement attributeForName:@"name"] stringValue] isEqualToString:[[secondElement attributeForName:@"name"] stringValue]]) {
            
            //combine attributes
            int totalTests = [[[mainElement attributeForName:@"tests"] stringValue] intValue] + [[[secondElement attributeForName:@"tests"] stringValue] intValue];
            int totalErrors = [[[mainElement attributeForName:@"errors"] stringValue] intValue] + [[[secondElement attributeForName:@"errors"] stringValue] intValue];
            int totalFailures = [[[mainElement attributeForName:@"failures"] stringValue] intValue] + [[[secondElement attributeForName:@"failures"] stringValue] intValue];
            int totalTime = [[[mainElement attributeForName:@"time"] stringValue] intValue] + [[[secondElement attributeForName:@"time"] stringValue] intValue];
            
            m_attributes[@"tests"] = [@(totalTests) stringValue];
            m_attributes[@"errors"] = [@(totalErrors) stringValue];
            m_attributes[@"failures"] = [@(totalFailures) stringValue];
            m_attributes[@"time"] = [@(totalTime) stringValue];
            
            //children
            if ([[mainElement.children firstObject].name isEqualToString:@"testcase"]
                && [[secondElement.children firstObject].name isEqualToString:@"testcase"]) {
                for (NSXMLNode *child in secondElement.children) {
                    [mainElement addChild:[child copy]];
                }
                
            } else {
            
                NSMutableArray<NSXMLNode *> *mergedChildren = [NSMutableArray<NSXMLNode *> new];
                NSMutableArray *discardedItems = [NSMutableArray array];
                NSMutableArray<NSXMLNode *> *m_children = [NSMutableArray arrayWithArray:mainElement.children];
                NSMutableArray<NSXMLNode *> *s_children = [NSMutableArray arrayWithArray:secondElement.children];
                
                for (NSXMLNode *m_node in m_children) {
                    if (m_node.kind != NSXMLElementKind) continue;
                    NSXMLElement *m_element = (NSXMLElement *)m_node;
                    
                    for (NSXMLNode *s_node in s_children) {
                        if (s_node.kind != NSXMLElementKind) continue;
                        NSXMLElement *s_element = (NSXMLElement *)s_node;
                        if ([self compareNamesForElement:m_element and:s_element]) {
                            m_element = [self mergeElement:m_element withElement:s_element];
                            [discardedItems addObject:s_node];
                        }
                    }
                    
                    [s_children removeObjectsInArray:discardedItems];
                    [mergedChildren addObject:m_element];
                }
                
                [mergedChildren addObjectsFromArray:s_children];
                
                [mainElement setChildren:nil];
                for (NSXMLNode *child in mergedChildren) {
                    [mainElement addChild:[child copy]];
                }
            }
            
            [mainElement setAttributesAsDictionary:m_attributes];
            return mainElement;
            
        } else {
            return nil;
        }
    }
}

+ (BOOL)compareNamesForElement:(NSXMLElement *)fistElement and:(NSXMLElement *)secondElement {
    
    NSString *firstName = [[fistElement attributeForName:@"name"] stringValue];
    NSString *secondName = [[secondElement attributeForName:@"name"] stringValue];
    if (firstName == nil || secondName == nil) return false;
    return [firstName isEqualToString:secondName];
}

@end
