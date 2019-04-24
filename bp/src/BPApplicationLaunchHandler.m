//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPApplicationLaunchHandler.h"
#import "BPWaitTimer.h"

@implementation BPApplicationLaunchHandler

- (ApplicationLaunchBlock)defaultHandlerBlock {
    return ^(NSError *error, pid_t pid) {
        dispatch_once(&self->onceToken, ^{
            [self.timer cancelTimer];

            self.error = error;
            self.pid = pid;

            if (self.beginWith) {
                self.beginWith();
            }

            if ((error || pid < 0)) {
                if (self.onError) {
                    self.onError(error);
                }
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
