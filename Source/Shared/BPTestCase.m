//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTestCase.h"

@implementation BPTestCase

-(instancetype)init {
    return [self initWithName:nil andTime:nil];
}

-(instancetype) initWithName:(NSString *)name {
    return [self initWithName:name andTime:nil];
}

-(instancetype) initWithName:(NSString *)name andTime:(NSNumber *)time {
    self = [super init];
    if (self) {
        self.name = name;
        self.time = time;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.time];
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"<%@: %p> %@", [self class], self, self.name];
}

@end
