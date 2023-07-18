//
//  BPTestInspectionHandler.h
//  bp
//
//  Created by Lucas Throckmorton on 7/17/23.
//  Copyright © 2023 LinkedIn. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <bplib/bplib.h>

@class BPTestCaseInfo;

typedef void (^TestInspectionBlock)(NSArray<BPTestCaseInfo *> *testBundleInfo, NSError *error);
typedef void (^TestInspectionSuccessBlock)(NSArray<BPTestCaseInfo *> *testBundleInfo);

@interface BPTestInspectionHandler : BPHandler

@property (nonatomic, copy) TestInspectionSuccessBlock onSuccess;

- (TestInspectionBlock)defaultHandlerBlock;



@end
