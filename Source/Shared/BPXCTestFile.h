//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@interface BPXCTestFile : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, assign) BOOL isUITestFile;
// All test classes in the test bundle
@property (nonatomic, strong) NSArray *testClasses;

+ (instancetype)BPXCTestFileFromExecutable:(NSString *)path
                              isUITestFile:(BOOL)isUITestFile
                                 withError:(NSError **)error;

- (NSUInteger)numTests;
- (NSArray *)allTestCases;
- (void)listTestClasses;
- (NSString *)description;

@end
