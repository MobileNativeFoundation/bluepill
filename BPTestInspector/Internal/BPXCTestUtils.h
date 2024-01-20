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

@interface BPXCTestUtils : NSObject

/**
 Given a path to an .xctest test bundle, this method will encode all of the contained test info into an output file.
 This information will be saved as data encoding for an `NSArray<BPTestCaseInfo *> *`, stored
 at the output path.
 
 @param bundlePath The path of the .xctest bundle
 @param outputPath The path of the output file.
 */
+ (void)logAllTestsInBundleWithPath:(NSString *)bundlePath toFile:(NSString *)outputPath;

@end

NS_ASSUME_NONNULL_END
