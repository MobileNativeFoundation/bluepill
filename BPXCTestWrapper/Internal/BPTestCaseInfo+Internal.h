//
//  BPTestCaseInfo+Internal.h
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 7/14/23.
//

#import <BPXCTestWrapper/BPTestCaseInfo.h>
#import "XCTestCase.h"

NS_ASSUME_NONNULL_BEGIN

@interface BPTestCaseInfo (Internal)

+ (instancetype)infoFromTestCase:(XCTestCase *)testCase;

@end

NS_ASSUME_NONNULL_END
