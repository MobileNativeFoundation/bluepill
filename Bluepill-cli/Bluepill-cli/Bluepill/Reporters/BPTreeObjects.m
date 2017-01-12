//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTreeObjects.h"

@implementation BPLogEntry

- (NSString *)debugDescription {
    return [self description];
}

@end

@implementation BPTestCaseLogEntry

- (NSString *)description {
    NSString *str = [NSString stringWithFormat:
                     @"\nTestClass: %@\ntestName: %@\nTime: %f\nEnded: %@\nPassed: %@\nFilename: %@\nLine number: %lu\nError Message: %@\nLog:\n%@\n",
                     self.testCaseClass, self.testCaseName, self.totalTime, self.ended ? @"YES" : @"NO", self.passed ? @"YES" : @"NO",
                     self.filename, self.lineNumber, self.errorMessage, self.log];
    return str;
}

@end

@implementation BPTestSuiteLogEntry

- (nullable BPTestCaseLogEntry *)testCaseWithClass:(NSString *)testCaseClass andName:(NSString *)testCaseName {
    for (BPLogEntry* logEntry in self.children) {
        if ([logEntry isKindOfClass:[BPTestCaseLogEntry class]]) {
            BPTestCaseLogEntry* testCaseLogEntry = (BPTestCaseLogEntry *)logEntry;
            if ([testCaseLogEntry.testCaseClass isEqualToString:testCaseClass] &&
                [testCaseLogEntry.testCaseName isEqualToString:testCaseName]) {
                return testCaseLogEntry;
            }
        }
    }
    return nil;
}

- (void)addChild:(BPLogEntry *)logEntry {
    if (!self.children) {
        self.children = [[NSMutableArray alloc] init];
    }
    [self.children addObject:logEntry];
}

- (NSString *)description {
    NSString *str = [NSString stringWithFormat:@"\nTest: %@\nStart: %@\nEnd: %@\nEnded: %@\nPassed: %@\nTotal: %lu\nFail: %lu\nUnexpected: %lu\nTime: %f\nLog:\n%@\n",
                     self.testSuiteName, self.startTime, self.endTime, self.ended ? @"YES" : @"NO", self.passed ? @"YES" : @"NO",
                     self.numberOfTests, self.numberOfFailures, self.numberOfUnexpected, self.totalTime, self.log];
    for (BPLogEntry *child in self.children) {
        str = [str stringByAppendingString:[child description]];
    }
    return str;
}

@end
