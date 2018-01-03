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
                     @"%@/%@ Time: %f Ended: %@ Passed: %@ Filename: %@ Line number: %lu Error Message: %@ Log: %@\n",
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
    NSString *str = [NSString stringWithFormat:@"\nTestSuite: %@ Start: %@ End: %@ Ended: %@ Passed: %@ "
                     "Total: %lu Fail: %lu Errors: %lu Time: %f Log: \n---\n%@\n---\n",
                     self.testSuiteName, self.startTime, self.endTime, self.ended ? @"YES" : @"NO", self.passed ? @"YES" : @"NO",
                     self.numberOfTests, self.numberOfFailures, self.numberOfErrors, self.totalTime, self.log];
    for (BPLogEntry *child in self.children) {
        NSString *childDescription = [@"\n    " stringByAppendingString:[child description]];
        str = [str stringByAppendingString:childDescription];
    }
    return str;
}

@end
