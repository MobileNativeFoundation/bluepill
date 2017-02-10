//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTestClass.h"

@implementation BPTestClass

-(instancetype)init {
    return [self initWithName:nil];
}

-(instancetype)initWithName:(NSString *)name {
    self = [super init];
    if (self) {
        self.name = name;
        self.testCases = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)addTestCase:(BPTestCase *)testCase {
    [self.testCases addObject:testCase];
}

- (NSUInteger)numTests {
    return [self.testCases count];
}

- (void)listTestCases {
    for (BPTestCase *testCase in self.testCases) {
        printf("  %s/%s\n", [self.name UTF8String], [testCase.name UTF8String]);
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ / %lu testCases", self.name, [self.testCases count]];
}

- (NSString *)debugDescription
{
    NSString *testcases = [self.testCases componentsJoinedByString:@","];
    return [NSString stringWithFormat:@"<%@: %p> %@ - %lu - %@", [self class], self, self.name, self.testCases.count, testcases];
}

@end
