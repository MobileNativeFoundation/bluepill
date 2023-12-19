//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 This class is a basic representation of an XCTestCase, with all the information required to
 add the test to an include/exclude list when specifying what tests to run in an xctest execution.
 
 Notably, this class conforms to NSSecureCoding so that it can be encoded, piped out to a
 parent execution, and then decoded.
 */
@interface BPTestCaseInfo : NSObject<NSSecureCoding>

@property (nonatomic, copy, nonnull, readonly) NSString *className;
@property (nonatomic, copy, nonnull, readonly) NSString *methodName;

/**
 The name of the test, formatted correctly for XCTest (regardless of Obj-C vs Swift)

 @example `MyTestClass/MyTestCase` in Obj-C, or `MyTestModule.MyTestClass/MyTestCase` in Swift
 */
@property (nonatomic, copy, nonnull, readonly) NSString *standardizedFullName;
/**
 The name of the test, formatted according to how BP consumers expect to list the test
 in the opt-in or skip lists, or how they should be displayed in the generated test results.
 
 @example `MyTestClass/MyTestCase` in Obj-C, or `MyTestClass/MyTestCase()` in Swift
 */
@property (nonatomic, copy, nonnull, readonly) NSString *prettifiedFullName;

@end

NS_ASSUME_NONNULL_END
