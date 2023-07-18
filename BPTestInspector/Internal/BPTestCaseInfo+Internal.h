//
//  BPTestCaseInfo+Internal.h
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 7/14/23.
//

#import <BPTestInspector/BPTestCaseInfo.h>

@class XCTestCase;

NS_ASSUME_NONNULL_BEGIN

@interface BPTestCaseInfo (Internal)

+ (instancetype)infoFromTestCase:(XCTestCase *)testCase;

#pragma mark - Testing

- (instancetype)initWithClassName:(NSString *)className
                       methodName:(NSString *)methodName;

@end

NS_ASSUME_NONNULL_END
