//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@interface BPXCTestFile : NSObject <NSCopying>

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray<NSString *> *commandLineArguments;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *environmentVariables;
@property (nonatomic, strong) NSString *testHostPath;
@property (nonatomic, strong) NSString *testHostBundleIdentifier;
@property (nonatomic, strong) NSString *testBundlePath;
@property (nonatomic, strong) NSString *UITargetAppPath;
@property (nonatomic, strong) NSArray<NSString *> *skipTestIdentifiers;

// All test classes in the test bundle
@property (nonatomic, strong) NSArray *testClasses;

+ (instancetype)BPXCTestFileFromXCTestBundle:(NSString *)testBundlePath
                            andHostAppBundle:(NSString *)testHostPath
                                   withError:(NSError **)error;

+ (instancetype)BPXCTestFileFromXCTestBundle:(NSString *)testBundlePath
                            andHostAppBundle:(NSString *)testHostPath
                          andUITargetAppPath:(NSString *)UITargetAppPath
                                   withError:(NSError **)error;

+ (instancetype)BPXCTestFileFromDictionary:(NSDictionary<NSString *, NSString *>*) dict
                              withTestRoot:(NSString *)testRoot
                              andXcodePath:(NSString *)xcodePath
                                  andError:(NSError **)error;

- (NSUInteger)numTests;
- (NSArray *)allTestCases;
- (void)listTestClasses;
- (NSString *)description;
- (NSString *)debugDescription;
@end
