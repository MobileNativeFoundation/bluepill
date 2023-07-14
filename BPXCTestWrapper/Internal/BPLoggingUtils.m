//
//  BPLoggingUtils.m
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import "BPLoggingUtils.h"

@implementation BPLoggingUtils

+ (void)log:(NSString *)message {
    NSLog(@"[BPXCTestWrapper] %@", message);
}

+ (void)logError:(NSString *)errorMessage {
    NSLog(@"[BPXCTestWrapper] Error: %@", errorMessage);
}

@end
