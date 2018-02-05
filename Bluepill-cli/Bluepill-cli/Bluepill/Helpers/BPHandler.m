//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPHandler.h"
#import "BPWaitTimer.h"
#import "BPConstants.h"

@implementation BPHandler

+ (instancetype)handlerWithTimer:(BPWaitTimer *)timer {
    BPHandler *handler = [[self alloc] init];
    handler.timer = timer;
    [handler setup];
    return handler;
}

- (void)setup {
    __weak typeof(self) __self = self;
    self.timer.onTimeout = ^{
        BPHandler *strongSelf = __self;
        if (strongSelf) {
            dispatch_once(&strongSelf->onceToken, ^{
                if (__self.onTimeout) {
                    __self.onTimeout();
                }
                // call timeout block first and then execute the onError block
                if (__self.onError) {
                    NSError *error = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:@{@"NSLocalizedDescriptionKey" : @"timeout"}];
                    __self.onError(error);
                }
            });
        }
    };
}

- (BasicErrorBlock)defaultHandlerBlock {
    return ^(NSError *error) {
        dispatch_once(&self->onceToken, ^{
            [self.timer cancelTimer];

            self.error = error;

            if (self.beginWith) {
                self.beginWith();
            }

            if (error && self.onError) {
                self.onError(error);
            } else if (self.onSuccess) {
                self.onSuccess();
            }

            if (self.endWith) {
                self.endWith();
            }
        });
    };
}

@end
