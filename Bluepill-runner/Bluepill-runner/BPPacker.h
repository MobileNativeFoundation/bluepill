//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>
#import "BPConfiguration.h"

@interface BPPacker : NSObject

/*!
 * @discussion Pack a series of .xctest bundles into an NSArray of NSString with the testcases distributed according to the packing rules.
 * @param xcTestFiles An NSArray of BPXCTestFile's to pack
 * @param config The configuration file for this bluepill-runner
 * @return An NSMutableArray of BPBundle's with the tests packed into bundles.
 */
+ (NSMutableArray *)packTests:(NSArray *)xcTestFiles
                configuration:(BPConfiguration *)config
                     andError:(NSError **)error;

@end
