//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@protocol BPMonitorCallbackProtocol;

@protocol BPExecutionPhaseProtocol <NSObject>

- (void)setMonitorCallback:(id<BPMonitorCallbackProtocol>)callback;

- (void)onAllTestsBegan;

- (void)onAllTestsEnded;

- (void)onTestSuiteBegan:(NSString *)testSuiteName onDate:(NSDate *)startDate isRoot:(BOOL)isRoot;

- (void)onTestSuiteEnded:(NSString *)testSuiteName
                  isRoot:(BOOL)isRoot;

- (void)onTestCaseBeganWithName:(NSString *)testName inClass:(NSString *)testClass;

- (void)onTestCasePassedWithName:(NSString *)testName inClass:(NSString *)testClass reportedDuration:(NSTimeInterval)duration;

- (void)onTestCaseFailedWithName:(NSString *)testName inClass:(NSString *)testClass inFile:(NSString *)filePath onLineNumber:(NSUInteger)lineNumber wasException:(BOOL)wasException;

- (void)onOutputReceived:(NSString *)output;

- (void)setParserStateCompleted;

@end

@protocol BPMonitorCallbackProtocol <NSObject>

- (void)onTestAbortedWithName:(NSString *)testName inClass:(NSString *)testClass errorMessage:(NSString *)message;

@end
