//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@class BPWaitTimer;

typedef void (^BPWaitTimerBlock)(BPWaitTimer *timer);
typedef void (^BPWaitTimerTimeoutBlock)(void);

/**
 This class will call the specified timeout block if the
 specified time elapses before the @c[cancelTimer] method is called.
 */
@interface BPWaitTimer : NSObject

@property (nonatomic, copy) BPWaitTimerTimeoutBlock onTimeout;
@property (nonatomic, assign) NSTimeInterval interval;

+ (instancetype)timerWithInterval:(NSTimeInterval)interval;

- (void)start;

- (BOOL)isCompleted;

- (void)cancelTimer;

@end
