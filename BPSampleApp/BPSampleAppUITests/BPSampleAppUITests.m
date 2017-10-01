//
//  BPSampleAppUITests.m
//  BPSampleAppUITests
//
//  Created by Keqiu Hu on 1/23/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

@import XCTest;
@interface BPSampleAppUITests : XCTestCase
@property XCUIApplication *app;
@end

@implementation BPSampleAppUITests
- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    [self.app launch];
    [self.app.buttons[@"Tap Me"] tap];
    XCUIElement *textField = [[self.app.otherElements containingType:XCUIElementTypeButton identifier:@"Tap Me"] childrenMatchingType:XCUIElementTypeTextField].element;
    [textField tap];
    [textField typeText:@"keqiu"];
}

- (void)testExample2 {
    [self.app launch];
    [self.app.buttons[@"Tap Me"] tap];
    XCUIElement *textField = [[self.app.otherElements containingType:XCUIElementTypeButton identifier:@"Tap Me"] childrenMatchingType:XCUIElementTypeTextField].element;
    [textField tap];
    [textField typeText:@"huhuhu"];
}

@end
