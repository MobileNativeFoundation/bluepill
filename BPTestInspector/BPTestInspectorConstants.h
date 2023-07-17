//
//  BPTestInspectorConstants.h
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 7/13/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BPTestInspectorConstants : NSObject

+ (NSString *)dylibName;
+ (NSString *)testBundleEnvironmentKey;
+ (NSString *)outputPathEnvironmentKey;

@end

NS_ASSUME_NONNULL_END
