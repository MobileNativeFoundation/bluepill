//
//  BPTestSuiteUtils.h
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BPXCTestUtils : NSObject

+ (void)logAllTestsInBundleWithPath:(NSString *)bundlePath toFile:(NSString *)outputPath;

@end

NS_ASSUME_NONNULL_END
