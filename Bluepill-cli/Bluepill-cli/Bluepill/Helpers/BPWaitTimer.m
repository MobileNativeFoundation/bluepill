//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPWaitTimer.h"

@interface BPWaitTimer ()
@property (atomic, strong) dispatch_source_t timer;
@end

@implementation BPWaitTimer

+ (instancetype)timerWithInterval:(NSTimeInterval)interval {
    BPWaitTimer *timer = [[self alloc] init];
    timer.interval = interval;
    return timer;
}

- (void)start {
    [self startTimerFor:self.interval withCompletion:^{
        if (self.onTimeout) {
            self.onTimeout();
        }
    }];
}

- (void)startTimerFor:(NSTimeInterval)seconds withCompletion:(void (^)(void))block {
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
    __weak typeof(self) __self = self;
    dispatch_source_set_timer(self.timer, dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(self.timer, ^{
        // In case we fire even though the timer was canceled
        if (![__self isCompleted]) {
            [__self cancelTimer];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) {
                    block();
                }
            });
        }
    });
    dispatch_resume(self.timer);
}

- (void)cancelTimer {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
    } else {
        NSLog(@"WTF? self.timer is nil??");
    }
    self.timer = nil;
}

- (BOOL)isCompleted {
    return (self.timer == nil);
}
@end
