////
////  XCTestLog+Shim.m
////  Experiment
////
////  Created by Lucas Throckmorton on 5/29/23.
////
//
//#import "XCTestLog+Shim.h"
//
//#import <Foundation/Foundation.h>
//#import <objc/runtime.h>
//#import "XCTestSuiteRun.h"
//#import "XCTestCase.h"
//
//#import "BPShimLogger.h"
//
//static NSString *swizzlePrefix = @"bpLogicTestShim";
//
//#pragma mark - Private Interface
//
//@interface XCTestLog (Shim_Private)
//
//@property (nonatomic, strong, nullable) NSTimer *testSuiteTimer;
//@property (nonatomic, strong, nullable) NSTimeZone *testCaseTimer;
//
//@end
//
//#pragma mark - Implementation
//
//@implementation XCTestLog (Shim)
//
//#pragma mark - constants
//
//+ (NSArray<NSString *> *)swizzledTestLogMethodNames {
//    return @[
//        @"testSuiteWillStart:",
//        @"testSuiteDidFinish:",
//        @"testCaseWillStart:",
//        @"testCaseDidFinish:",
//        @"testCaseDidFail:withDescription:inFile:atLine:",
//        @"testCase:wasSkippedWithDescription:inFile:atLine:",
//    ];
//}
//
//#pragma mark - load
//
//+ (void)load {
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        Class class = [self class];
//        for (NSString *methodName in self.swizzledTestLogMethodNames) {
//            NSString *newMethodName = [NSString stringWithFormat:@"%@_%@", swizzlePrefix, methodName];
//            SEL originalSelector = NSSelectorFromString(methodName);
//            SEL swizzledSelector = NSSelectorFromString(newMethodName);
//            
//            Method originalMethod = class_getInstanceMethod(class, originalSelector);
//            Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
//            
//            method_exchangeImplementations(originalMethod, swizzledMethod);
//        }
//    });
//}
//
//#pragma mark - XCTestLog Lifecycle
//
//// TODO: set up timer per test suite and per test case
//
//- (void)bpLogicTestShim_testSuiteWillStart:(XCTestSuite *)suite {
//    [BPShimLogger.defaultLogger log:@"testSuiteWillStart: called"];
//    [self bpLogicTestShim_testSuiteWillStart:suite];
//}
//
//- (void)bpLogicTestShim_testSuiteDidFinish:(XCTestSuite *)suite {
//    [BPShimLogger.defaultLogger log:@"testSuiteDidFinish: called"];
//    [self bpLogicTestShim_testSuiteDidFinish:suite];
//}
//
//- (void)bpLogicTestShim_testCaseWillStart:(XCTestCase *)testCase {
//    [BPShimLogger.defaultLogger log:@"testCaseWillStart: called"];
//    [self bpLogicTestShim_testCaseWillStart:testCase];
//}
//
//- (void)bpLogicTestShim_testCaseDidFinish:(XCTestCase *)testCase {
//    [BPShimLogger.defaultLogger log:@"testCaseDidFinish: called"];
//    [self bpLogicTestShim_testCaseDidFinish:testCase];
//    
//}
//
//- (void)bpLogicTestShim_testCase:(XCTestCase *)testCase
//          didFailWithDescription:(NSString *)description
//                          inFile:(NSString *)file
//                          atLine:(NSUInteger)line {
//    [BPShimLogger.defaultLogger log:@"testCase:didFailWithDescription:inFile:atLine: called"];
//    [self bpLogicTestShim_testCase:testCase
//            didFailWithDescription:description
//                            inFile:file
//                            atLine:line];
//}
//
//- (void)bpLogicTestShim_testCase:(XCTestCase *)testCase
//       wasSkippedWithDescription:(NSString *)description
//                          inFile:(NSString *)file
//                          atLine:(unsigned long long)line {
//    [BPShimLogger.defaultLogger log:@"testCase:wasSkippedWithDescription:inFile:atLine: called"];
//    [self bpLogicTestShim_testCase:testCase
//         wasSkippedWithDescription:description
//                            inFile:file
//                            atLine:line];
//}
//
//@end
