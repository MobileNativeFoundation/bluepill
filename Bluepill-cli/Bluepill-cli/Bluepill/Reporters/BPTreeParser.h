//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

// Test Suite 'mntf_UISwiftTests' started at 2016-10-07 12:52:05.091
// Test Suite 'Debug-iphonesimulator' passed at 2016-10-07 12:52:05.091.
// Test Suite 'mntf_UISwiftTests' failed at 2016-10-07 12:52:08.297.
#define TEST_SUITE_START @"Test Suite \\'(.*)\\' (\\w*) at (.*:.{2}\\.\\d*)\\.?"

// 	 Executed 9 tests, with 2 failures (1 unexpected) in 2.980 (3.206) seconds
#define TEST_SUITE_ENDED @"Executed (\\d*) test.?, with (\\d*) failure.? \\((\\d*) unexpected\\) in ([\\d\\.]*) \\(([\\d\\.]*)\\) seconds"

// Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' started.
#define TEST_CASE_STARTED @"Test Case '-\\[(.*) (.*)\\]' started\\."

// /Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:67: error: -[mntf_iosUITests.mntf_UISwiftTests testAdd] : XCTAssertTrue failed - This doesn't contain the string we're looking for!
// /Users/agandhi/Documents/Source/msg/mntf-ios_trunk/mntf-iosUITests/mntf_iosUISwiftTests.swift:75: error: -[mntf_iosUITests.mntf_UISwiftTests testGetName] : failed: caught "MyException", "My Reason"
// /export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_7dee32c1fdb9facfff35737351eeab72cfa90126/Testing/VoyagerIntTestsLib/Shared/VoyagerIntTestCase.swift:172: error: -[VoyagerFeedIndividualPageTests.FeedEmptyFeedVariant1SplashTest testHighlightedDeepLinkEmptyFeedHidden] : The step timed out after 10.00 seconds: Waiting for notification "concurrent_dispatch_queue_finish"
#define TEST_CASE_FAILED @"(.*):(\\d+): error: -\\[(.*) (.*)\\] : (.*)"

#define UITEST_CASE_FAILED @".*Assertion Failure:([^:]*):(\\d+): (.*) .*"

// fatal error: unexpectedly found nil while unwrapping an Optional value
#define TEST_CASE_CRASHED @"fatal error: (.*)"

// stack trace for SIGNAL 11 (Segmentation fault: 11):
#define TEST_CASE_CRASHED2 @"(stack trace for .*)"

// *** Assertion failure in -[UICollectionView _dequeueReusableViewOfKind:withIdentifier:forIndexPath:viewCategory:], /BuildRoot/Library/Caches/com.apple.xbs/Sources/UIKit_Sim/UIKit-3600.5.2/UICollectionView.m:4922
#define TEST_CASE_CRASHED3 @"\\*\\*\\* (Assertion failure in .*), (.*):(.*)"

// /export/home/tester/hudson/data/workspace/MP_TRUNKDEV_DISTRIBUTED_TEST/voyager-ios_b7eadfa63fdc85ff5143ed9ff580bb1a9ab7bc25/Testing/VoyagerIdentityTests/Me/Notifications/MeFeedAggregatePropCardTest.swift:421: error: -[VoyagerMeTests.MeFeedAggregatePropCardTest testExpandableAggregatePropCard] : Error Domain=com.LIMixture.MixtureProtocol.MixtureValidator Code=-101 "(null)" UserInfo={CapturedTrackingEvents=(
#define TEST_CASE_CRASHED4 @"(\\/.*):(.*): error: (.*)"

// Test Case '-[mntf_iosUITests.mntf_UISwiftTests testWaitForCheckpoint]' passed (1.037 seconds).
#define TEST_CASE_PASSED @"Test Case '-\\[(.*) (.*)\\]' (\\w*) \\(([\\d\\.]*) seconds\\)\\."

@protocol BPReporter;
@protocol BPExecutionPhaseProtocol;

@class BPWriter;

@interface BPTreeParser : NSObject

@property (nonatomic, weak, nullable) id<BPExecutionPhaseProtocol> delegate;

- (nonnull instancetype)initWithWriter:(nonnull BPWriter *)writer;

- (void)handleChunkData:(nonnull NSData *)chunk;
- (void)completed;
- (void)completedFinalRun;
- (void)cleanup;
- (nullable NSString *)generateLog:(nonnull id<BPReporter>)reporter;

@end
