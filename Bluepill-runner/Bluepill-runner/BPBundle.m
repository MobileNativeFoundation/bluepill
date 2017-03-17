//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPBundle.h"

@implementation BPBundle

- (instancetype)init {
    return [self initWithPath:nil isUITestBundle:NO andTestsToSkip:nil];
}

- (instancetype)initWithPath:(NSString *)path
              isUITestBundle:(BOOL)isUITest
              andTestsToSkip:(NSArray *)tests {
    self = [super init];
    if (self) {
        self.path = path;
        self.isUITestBundle = isUITest;
        self.testsToSkip = tests;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ - %lu tests", [self.path lastPathComponent], self.testsToSkip.count];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@ / %lu tests skipped: %@",
            [self class],
            self,
            [self.path lastPathComponent],
            self.testsToSkip.count,
            [self.testsToSkip componentsJoinedByString:@", "]];
}

@end
