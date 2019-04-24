//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPTreeAssembler.h"
#import "BPStats.h"

@implementation BPTreeAssembler

+ (instancetype)sharedInstance {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)testAborted:(NSString *)testName inClass:(NSString *)testClass {

}

- (void)reset {
    self.root = nil;
    self.current = nil;
    self.currentTest = nil;
    [BPStats sharedStats].cleanRun = YES;
}
@end
