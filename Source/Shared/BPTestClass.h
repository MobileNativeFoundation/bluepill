//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPTestCase.h"

@interface BPTestClass : NSObject

@property (nonatomic) NSString *name;
@property (nonatomic) NSMutableArray *testCases;

- (instancetype)initWithName: (NSString *)name;
- (void)addTestCase:(BPTestCase *)testCase;
- (NSUInteger)numTests;
- (NSString *)description;
- (NSString *)debugDescription;
- (void)listTestCases;
@end
