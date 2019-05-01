//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@interface BPLogEntry : NSObject

@property (nonatomic, assign) NSTimeInterval totalTime;
@property (nonatomic, strong, nullable) NSString *line;
@property (nonatomic, strong, nullable) NSString *log;
@property (nonatomic, assign) BOOL ended;
@property (nonatomic, assign) BOOL passed;
@property (nonatomic, assign) BOOL failure;
@property (nonatomic, strong, nullable) NSDate *startTime;
@property (nonatomic, strong, nullable) NSDate *endTime;

@end

@interface BPTestCaseLogEntry : BPLogEntry

@property (nonatomic, strong, nullable) NSString *testCaseClass;
@property (nonatomic, strong, nullable) NSString *testCaseName;

@property (nonatomic, strong, nullable) NSString *filename;
@property (nonatomic, assign) NSUInteger lineNumber;
@property (nonatomic, strong, nullable) NSString *errorMessage;

@end

@interface BPTestSuiteLogEntry : BPLogEntry

@property (nonatomic, strong, nullable) NSString *testSuiteName;

// These are computed by the parser as it reads the output
@property (nonatomic, assign) NSUInteger numberOfTests;
@property (nonatomic, assign) NSUInteger numberOfFailures; // Failures == crashes, unhandled exceptions, etc
@property (nonatomic, assign) NSUInteger numberOfErrors; // Errors == XCTAsserts that fail

@property (nonatomic, strong, nullable) NSMutableArray<BPLogEntry*> *testCases;

@property (nonatomic, strong, nullable) NSMutableArray<BPLogEntry*> *children;
@property (nonatomic, weak, nullable) BPTestSuiteLogEntry *parent;

// These next come from XCTest's own summarizer and are used to do verify we are getting the same counts
// as the ones above
@property (nonatomic, assign) NSTimeInterval reportedTotalTime;
@property (nonatomic, assign) NSUInteger reportedNumberOfTests;
@property (nonatomic, assign) NSUInteger reportedNumberOfFailures;
@property (nonatomic, assign) NSUInteger reportedNumberOfErrors;

- (void)addChild:(nonnull BPLogEntry *)logEntry;
- (nullable BPTestCaseLogEntry *)testCaseWithClass:(nonnull NSString *)testCaseClass andName:(nonnull NSString *)testCaseName;
@end
