//
//  BPTestCaseInfo.m
//  BPXCTestWrapper
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import "BPTestCaseInfo+Internal.h"

@implementation BPTestCaseInfo

- (instancetype)initWithModuleName:(NSString *)moduleName
                         className:(NSString *)className
                        methodName:(NSString *)methodName {
    if (self = [super init]) {
        _moduleName = moduleName;
        _className = className;
        _methodName = methodName;
        _fullNamespace = [NSString stringWithFormat:@"%@.%@/%@", moduleName, className, methodName];
    }
    return self;
}


+ (instancetype)infoFromTestCase:(XCTestCase *)testCase {
    NSString *moduleName = @"LTHROCKM - TODO";
    NSString *className = NSStringFromClass(testCase.class);
    NSString *methodName = [testCase respondsToSelector:@selector(languageAgnosticTestMethodName)] ? [testCase languageAgnosticTestMethodName] : NSStringFromSelector([testCase.invocation selector]);
    return [[BPTestCaseInfo alloc] initWithModuleName: moduleName className:className methodName:methodName];

}

#pragma mark - NSCoding

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.moduleName forKey:@"moduleName"];
    [coder encodeObject:self.className forKey:@"className"];
    [coder encodeObject:self.methodName forKey:@"methodName"];
    [coder encodeObject:self.fullNamespace forKey:@"fullNamespace"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    return [self initWithModuleName:[coder decodeObjectForKey:@"moduleName"]
                          className:[coder decodeObjectForKey:@"className"]
                        methodName:[coder decodeObjectForKey:@"methodName"]];

}

@end
