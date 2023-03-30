//
//  BPTestUtils.h
//  bp-tests
//
//  Created by Lucas Throckmorton on 2/17/23.
//  Copyright © 2023 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BPConfiguration;

NS_ASSUME_NONNULL_BEGIN

@interface BPTestUtils : NSObject

+ (nonnull BPConfiguration *)makeUnhostedTestConfiguration;

+ (nonnull BPConfiguration *)makeHostedTestConfiguration;

@end

NS_ASSUME_NONNULL_END
