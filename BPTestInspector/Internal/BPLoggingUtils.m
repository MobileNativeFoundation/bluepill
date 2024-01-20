//
//  BPLoggingUtils.m
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import "BPLoggingUtils.h"

@implementation BPLoggingUtils

+ (void)log:(NSString *)message {
    NSLog(@"[BPTestInspector] %@", message);
}

+ (void)logError:(NSString *)errorMessage {
    NSLog(@"[BPTestInspector] Error: %@", errorMessage);
}

@end
