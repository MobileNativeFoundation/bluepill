//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@interface TraceEvent  : NSObject
@property (strong, nonatomic) NSMutableArray *traceEvents;
@property (strong, nonatomic) NSString *displayTimeUnit;
@property (strong, nonatomic) NSString *systemTraceEvents;
@property (strong, nonatomic) NSDictionary *otherData;
@property (strong, nonatomic) NSDictionary *stackFrames;
@property (strong, nonatomic) NSArray *samples;
- (id) init;
- (instancetype)initWithData:(NSDictionary *)data;
- (void)appendCompleteTraceEvent:(NSString *)name
                                        :(NSString *)cat
                                        :(NSInteger)ts
                                        :(float)dur
                                        :(NSInteger)pid
                                        :(NSInteger)tid
                                        :(NSDictionary *)args;
- (NSDictionary *)toDict;
@end

@interface BPReportCollector : NSObject

/*!
 * @discussion collect xml reports from the reportsPath(recursive) and output a finalized report at finalReportPath
 * @param reportsPath parent path to the reports
 * @param finalReportPath the path to save the final report
 */
+ (void)collectReportsFromPath:(NSString *)reportsPath
             onReportCollected:(void (^)(NSURL *fileUrl))fileHandler
                  outputAtPath:(NSString *)finalReportPath;

+ (void)collectReportsFromPath:(NSString *)reportsPath
                 withOtherData:(NSDictionary *)otherData
                   applyXQuery:(NSString *)XQuery
                 hideSuccesses:(BOOL)hideSuccesses
          withTraceEventAtPath:(NSString *)finalReportPath;
@end

