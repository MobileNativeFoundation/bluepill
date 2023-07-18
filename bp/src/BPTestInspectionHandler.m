//
//  BPTestInspectionHandler.m
//  bp
//
//  Created by Lucas Throckmorton on 7/17/23.
//  Copyright © 2023 LinkedIn. All rights reserved.
//

#import "BPTestInspectionHandler.h"

#import <BPTestInspector/BPTestCaseInfo.h>

@implementation BPTestInspectionHandler

@dynamic onSuccess;

- (TestInspectionBlock)defaultHandlerBlock {
    return ^(NSArray<BPTestCaseInfo *> *testBundleInfo, NSError *error) {
        dispatch_once(&self->onceToken, ^{
            [self.timer cancelTimer];

            self.error = error;

            if (self.beginWith) {
                self.beginWith();
            }

            if (error) {
                if (self.onError) {
                    self.onError(error);
                }
            } else if (self.onSuccess) {
                self.onSuccess(testBundleInfo);
            }

            if (self.endWith) {
                self.endWith();
            }
        });
    };
}

@end
