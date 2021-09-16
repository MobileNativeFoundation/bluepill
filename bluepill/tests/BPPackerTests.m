//
//  BPPackerTests.m
//  Bluepill
//
//  Created by Keqiu Hu on 6/19/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "bluepill/src/BPRunner.h"
#import "bluepill/src/BPApp.h"
#import "bluepill/src/BPPacker.h"
#import "bp/tests/BPTestHelper.h"
#import "bp/src/BPConfiguration.h"
#import "bp/src/BPUtils.h"
#import "bp/src/BPXCTestFile.h"
#import "bp/src/BPConstants.h"

@interface BPPackerTests : XCTestCase
@property (nonatomic, strong) BPConfiguration* config;
@end

@implementation BPPackerTests

- (void)setUp {
    [super setUp];

    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [BPConfiguration new];
    self.config.program = BLUEPILL_BINARY;
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.failureTolerance = @0;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.headlessMode = NO;
}

- (void)tearDown {
    self.config.testCasesToSkip = @[];
    [super tearDown];
}

- (void)testPackingWithXctFileContainingSkipTestIdentifiers {
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.numSims = @2;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    app.testBundles[0].skipTestIdentifiers = @[@"BPSampleAppTests/testCase000", @"BPSampleAppTests/testCase001"];

    NSArray<BPXCTestFile *> *bundles;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    for (BPXCTestFile *file in app.testBundles) {
        XCTAssert([file.skipTestIdentifiers containsObject: @"BPSampleAppTests/testCase000"]);
        XCTAssert([file.skipTestIdentifiers containsObject: @"BPSampleAppTests/testCase001"]);
    }
}

- (void)testPackingProvidesBalancedBundles {
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.numSims = @8;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSMutableArray *testCasesToSkip = [NSMutableArray new];
    for (BPXCTestFile *xctFile in app.testBundles) {
        [testCasesToSkip addObjectsFromArray:xctFile.allTestCases];
    }
    for (long i = 1; i <= 8; i++) {
        [testCasesToSkip removeObject:[NSString stringWithFormat:@"BPSampleAppTests/testCase%03ld", i]];
    }
    self.config.testCasesToSkip = testCasesToSkip;
    XCTAssert(app != nil);
    NSArray<BPXCTestFile *> *bundles;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    for (long i = 1; i <= 8; i++) {
        BPXCTestFile *bpBundle = bundles[i - 1];
        NSString *testThatShouldExist = [NSString stringWithFormat:@"BPSampleAppTests/testCase%03ld", i];
        XCTAssertFalse([bpBundle.skipTestIdentifiers containsObject:testThatShouldExist]);
    }
}

- (void)testSmartPackIfJsonFound {
    self.config.testTimeEstimatesJsonFile = [BPTestHelper sampleTimesJsonPath];
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase000"];
    self.config.numSims = @8;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSArray<BPXCTestFile *> *bundles;
    NSError *error;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:&error];
    XCTAssert(error ==  nil);
    XCTAssert([bundles count] >= [app.testBundles count]);
}

- (void)testSmartSplitting {
    self.config.testTimeEstimatesJsonFile = [BPTestHelper sampleTimesJsonPath];
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase000"];
    self.config.numSims = @8;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSError *error;
    // load the config file
    NSDictionary<NSString *, NSNumber *> *testTimes = [BPUtils loadSimpleJsonFile:self.config.testTimeEstimatesJsonFile withError:&error];
    XCTAssert(error == nil);

    double totalTime = [BPUtils getTotalTimeWithConfig:self.config
                                             testTimes:testTimes
                                        andXCTestFiles:app.testBundles];
    double optimalBundleTime = totalTime / [[self.config numSims] floatValue];
    NSArray<BPXCTestFile *> *splitBundles;
    splitBundles = [BPPacker packTests:app.testBundles configuration:self.config andError:&error];

    XCTAssert(error ==  nil);
    XCTAssert([splitBundles count] >= [app.testBundles count]);
    for (BPXCTestFile *bundle in splitBundles) {
        XCTAssert([bundle.estimatedExecutionTime doubleValue] <= optimalBundleTime);
    }
}

- (void)testSmartPackIfJsonMissing {
    self.config.testTimeEstimatesJsonFile = @"invalid/times/file/path.json";
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase000"];
    self.config.numSims = @8;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSArray<BPXCTestFile *> *bundles;
    NSError *error;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:&error];
    XCTAssert(error !=  nil);
    XCTAssert([bundles count] == 0);
}

- (void)testPackingWithMissingTimeEstimatesInJson {
    self.config.testTimeEstimatesJsonFile = [BPTestHelper sampleTimesJsonPath];
    self.config.testBundlePath = [BPTestHelper sampleAppNewTestsBundlePath];
    self.config.numSims = @4;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSArray<BPXCTestFile *> *bundles;
    NSError *error;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:&error];
    XCTAssert(error ==  nil);
    XCTAssert([bundles count] > self.config.numSims.intValue);
}

- (void)testSortByTimeEstimates {
    self.config.testTimeEstimatesJsonFile = [BPTestHelper sampleTimesJsonPath];
    self.config.testBundlePath = nil;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    XCTAssert([app.testBundles count] == 6);
    // Make sure we don't split when we don't want to
    self.config.numSims = @4;
    NSArray<BPXCTestFile *> *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    XCTAssert([bundles count] >= [app.testBundles count]);
    for (int i=0; i < bundles.count - 1; i++) {
        double estimate1 = [[[bundles objectAtIndex:i] estimatedExecutionTime] doubleValue];
        double estimate2 = [[[bundles objectAtIndex:(i+1)] estimatedExecutionTime] doubleValue];
        XCTAssert(estimate1 >= estimate2);
    }
}

- (void)testPackingWithNoSplitBundles {
    NSArray *want, *got;
    NSArray<BPXCTestFile *> *bundles;
    self.config.testBundlePath = nil;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    // Make sure we have the test bundles we expect. If we add more, this will pop but that's okay.
    // Just add the additional test bundles here.
    want = @[ @"BPAppNegativeTests.xctest",
              @"BPSampleAppCrashingTests.xctest",
              @"BPSampleAppFatalErrorTests.xctest",
              @"BPSampleAppHangingTests.xctest",
              @"BPSampleAppNewTests.xctest",
              @"BPSampleAppTests.xctest"];
    NSMutableArray *tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *bundle in app.testBundles) {
        [tests addObject:[bundle.testBundlePath lastPathComponent]];
    }
    got = [tests sortedArrayUsingSelector:@selector(compare:)];
    XCTAssert([want isEqualToArray:got]);

    // Make sure we don't split when we don't want to
    self.config.numSims = @4;
    self.config.noSplit = @[@"BPSampleAppTests", @"BPSampleAppNewTests"];
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    // When we prevent BPSampleTests from splitting, BPSampleAppFatalErrorTests and BPAppNegativeTests gets split in two
    want = [[want arrayByAddingObject:@"BPSampleAppFatalErrorTests"] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssertEqual(bundles.count, app.testBundles.count + 2);

    XCTAssertEqual([bundles[0].skipTestIdentifiers count], 0);
    XCTAssertEqual([bundles[1].skipTestIdentifiers count], 0);
    XCTAssertEqual([bundles[2].skipTestIdentifiers count], 0);
    XCTAssertEqual([bundles[3].skipTestIdentifiers count], 0);
    XCTAssertEqual([bundles[4].skipTestIdentifiers count], 1);
    XCTAssertEqual([bundles[5].skipTestIdentifiers count], 4);
    XCTAssertEqual([bundles[6].skipTestIdentifiers count], 1);
    XCTAssertEqual([bundles[7].skipTestIdentifiers count], 4);
}

- (void)testPackingCommonScenario {
    NSArray *allTests = [[NSMutableArray alloc] init];
    self.config.testBundlePath = nil;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);

    self.config.numSims = @4;
    self.config.noSplit = nil;
    NSArray<BPXCTestFile *> *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    // 5 unbreakable bundles (too few tests) and the big one broken into 4 bundles
    XCTAssertEqual(bundles.count, 9);

    // Let's gather all the tests and always make sure we get them all
    NSMutableArray *tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *testFile in app.testBundles) {
        [tests addObjectsFromArray:[testFile allTestCases]];
    }
    allTests = [tests sortedArrayUsingSelector:@selector(compare:)];

    // All we want to test is that we have full coverage
    long numSims = [[self.config numSims] integerValue];
    long testsPerBundle = MAX(1, [allTests count] / numSims);
    long testCount = 0;
    for (int i = 0; i < bundles.count; ++i) {
        if (i < 5) {
            XCTAssertEqual([bundles[i].skipTestIdentifiers count], 0);
            testCount += [[bundles[i] allTestCases] count];
        } else if (i < bundles.count-1) {
            long skipTestsPerBundle = ([[bundles[i] allTestCases] count] - testsPerBundle);
            XCTAssertEqual([bundles[i].skipTestIdentifiers count], skipTestsPerBundle);
            testCount += testsPerBundle;
        } else {  /* last bundle */
            long skipTestsInFinalBundle = [[bundles[i] allTestCases] count] - ([allTests count] - testCount);
            XCTAssertEqual([bundles[i].skipTestIdentifiers count], skipTestsInFinalBundle);
        }
    }
}

- (void)testPackingForOneSim {
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);

    self.config.numSims = @1;
    NSArray<BPXCTestFile *> *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    // If we pack into just one bundle, we can't have less bundles than the total number of .xctest files.
    XCTAssertEqual(bundles.count, app.testBundles.count);
}

- (void)testPackingFewerTestsThanSims {
    NSArray *allTests = [[NSMutableArray alloc] init];
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);

    self.config.numSims = @16;
    NSArray<BPXCTestFile *> *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];

    // Let's gather all the tests and always make sure we get them all
    NSMutableArray *tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *testFile in app.testBundles) {
        [tests addObjectsFromArray:[testFile allTestCases]];
    }
    allTests = [tests sortedArrayUsingSelector:@selector(compare:)];

    long numSims = [self.config.numSims integerValue];
    long testsPerBundle = MAX(1, [allTests count] / numSims);
    long testCount = 0;
    for (int i = 0; i < bundles.count; ++i) {
        if (i < bundles.count-1) {
            long skipTestsPerBundle = ([[bundles[i] allTestCases] count] - testsPerBundle);
            XCTAssertEqual([bundles[i].skipTestIdentifiers count], skipTestsPerBundle);
            testCount += testsPerBundle;
        } else {  /* last bundle */
            long skipTestsInFinalBundle = [[bundles[i] allTestCases] count] - ([allTests count] - testCount);
            XCTAssertEqual([bundles[i].skipTestIdentifiers count], skipTestsInFinalBundle);
        }
    }
}

- (void)testPackingSpecificTestsOnly {
    self.config.testBundlePath = nil;
    self.config.numSims = @4;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);

    NSMutableArray *toRun = [[NSMutableArray alloc] init];
    for (long i = 1; i <= 20; i++) {
        [toRun addObject:[NSString stringWithFormat:@"BPSampleAppTests/testCase%03ld", i]];
    }
    self.config.testCasesToRun = toRun;
    NSArray<BPXCTestFile *> *bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];

    long numSims = [self.config.numSims integerValue];
    XCTAssertEqual(bundles.count, numSims);
    long testsPerBundle = MAX(1, [self.config.testCasesToRun count] / numSims);
    for (int i=0; i < bundles.count; ++i) {
        if (i < bundles.count - 1) {
            long skipTestsPerBundle = ([[bundles[i] allTestCases] count] - testsPerBundle);
            XCTAssertEqual(bundles[i].skipTestIdentifiers.count, skipTestsPerBundle);
        } else {
            long skipTestsInFinalBundle = [[bundles[i] allTestCases] count] - ([self.config.testCasesToRun count] - (testsPerBundle * (numSims - 1)));
            XCTAssertEqual(bundles[i].skipTestIdentifiers.count, skipTestsInFinalBundle);
        }
    }
}

- (void)testPackingWithTestsToSkip {
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.testCasesToSkip = @[@"BPSampleAppTests/testCase000"];
    self.config.numSims = @8;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    NSArray<BPXCTestFile *> *bundles;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    for (BPXCTestFile *bundle in bundles) {
        XCTAssertTrue([bundle.skipTestIdentifiers containsObject:@"BPSampleAppTests/testCase000"], @"testCase000 should be in testToSkip for all bundles");
    }
}

@end
