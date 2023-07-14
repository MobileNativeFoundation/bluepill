//
//  BPLoggingUtils.h
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BPLoggingUtils : NSObject

+ (void)log:(NSString *)message;

+ (void)logError:(NSString *)errorMessage;

@end

NS_ASSUME_NONNULL_END
