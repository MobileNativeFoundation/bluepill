//
//  BPTestCaseInfo.m
//  BPTestInspector
//
//  Created by Lucas Throckmorton on 6/8/23.
//

#import "BPTestCaseInfo+Internal.h"
#import "XCTestCase.h"

@implementation BPTestCaseInfo

#pragma mark - Initializers

- (instancetype)initWithClassName:(NSString *)className
                       methodName:(NSString *)methodName {
    if (self = [super init]) {
        _className = [className copy];
        _methodName = [methodName copy];
    }
    return self;
}

+ (instancetype)infoFromTestCase:(XCTestCase *)testCase {
    NSString *className = NSStringFromClass(testCase.class);
    NSString *methodName = [testCase respondsToSelector:@selector(languageAgnosticTestMethodName)] ? [testCase languageAgnosticTestMethodName] : NSStringFromSelector([testCase.invocation selector]);
    return [[BPTestCaseInfo alloc] initWithClassName:className methodName:methodName];
}

#pragma mark - Properties

- (NSString *)standardizedFullName {
    return [NSString stringWithFormat:@"%@/%@", self.className, self.methodName];
}

- (NSString *)prettifiedFullName {
    /*
     If the class name contains a `.`, this is a Swift test case, and needs extra formatting.
     Otherwise, we in Obj-C, it's unchanged from the `standardizedFullName`
     */
    NSArray<NSString *> *classComponents = [self.className componentsSeparatedByString:@"."];
    if (classComponents.count < 2) {
        return self.standardizedFullName;
    }
    return [NSString stringWithFormat:@"%@/%@()", classComponents[1], self.methodName];
}

#pragma mark - Overrides

- (NSString *)description {
    return self.standardizedFullName;
}

- (BOOL)isEqual:(id)object {
    if (!object || ![object isMemberOfClass:BPTestCaseInfo.class]) {
        return NO;
    }
    BPTestCaseInfo *other = (BPTestCaseInfo *)object;
    return [self.className isEqual:other.className] && [self.methodName isEqual:other.methodName];
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
    [coder encodeObject:self.className forKey:@"className"];
    [coder encodeObject:self.methodName forKey:@"methodName"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
    return [self initWithClassName:[coder decodeObjectOfClass:NSString.class forKey:@"className"]
                        methodName:[coder decodeObjectOfClass:NSString.class forKey:@"methodName"]];

}

@end
