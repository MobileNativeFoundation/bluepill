//
//  BPTestCaseInfo.h
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BPTestCaseInfo : NSObject<NSCoding>

@property (nonatomic, copy, nonnull) NSString *moduleName;
@property (nonatomic, copy, nonnull) NSString *className;
@property (nonatomic, copy, nonnull) NSString *methodName;
@property (nonatomic, copy, nonnull) NSString *fullNamespace;

@end

NS_ASSUME_NONNULL_END
