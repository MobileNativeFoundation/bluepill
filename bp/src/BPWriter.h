//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@class BPConfiguration;

typedef NS_ENUM(NSInteger, BPWriterDestination) {
    BPWriterDestinationStdout,
    BPWriterDestinationStdErr,
    BPWriterDestinationFile
};

@interface BPWriter : NSObject

- (nonnull instancetype)initWithDestination:(BPWriterDestination)destination;
- (nonnull instancetype)initWithDestination:(BPWriterDestination)destination andPath:(nullable NSString *)filePath;

/*!
 * @discussion writes output to the destination specified on creation
 */
- (void)writeLine:(nonnull NSString *)format, ...;

/*!
 * @discussion writes output to stderr always
 */
- (void)writeError:(nonnull NSString *)format, ...;

/*!
 * @discussion remove the existing file, if any
 */
- (void)removeFile;

@end
