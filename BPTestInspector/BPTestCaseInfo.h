//
//  BPTestCaseInfo.h
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BPTestCaseInfo : NSObject<NSSecureCoding>

@property (nonatomic, copy, nonnull, readonly) NSString *className;
@property (nonatomic, copy, nonnull, readonly) NSString *methodName;

/**
 The name of the test, formatted correctly for XCTest (regardless of Obj-C vs Swift)

 @example `MyTestClass/MyTestCase` in Obj-C, or `MyTestModule.MyTestClass/MyTestCase` in Swift
 */
@property (nonatomic, copy, nonnull, readonly) NSString *standardizedFullName;
/**
 The name of the test, formatted according to how BP consumers expect to list the test
 in the opt-in or skip lists, or how they should be displayed in the generated test results.
 
 @example `MyTestClass/MyTestCase` in Obj-C, or `MyTestClass/MyTestCase()` in Swift
 */
@property (nonatomic, copy, nonnull, readonly) NSString *prettifiedFullName;

@end

NS_ASSUME_NONNULL_END
