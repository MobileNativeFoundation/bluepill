//
//  BPPackerTests.m
//  Bluepill
//
//  Created by Keqiu Hu on 6/19/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "BPTestHelper.h"
#import "BPConfiguration.h"
#import "BPUtils.h"
#import "BPRunner.h"
#import "BPApp.h"
#import "BPPacker.h"
#import "BPXCTestFile.h"
#import "BPConstants.h"

@interface BPPackerTests : XCTestCase
@property (nonatomic, strong) BPConfiguration* config;
@end

@implementation BPPackerTests

- (void)setUp {
    [super setUp];

    NSString *hostApplicationPath = [BPTestHelper sampleAppPath];
    NSString *testBundlePath = [BPTestHelper sampleAppNegativeTestsBundlePath];
    self.config = [BPConfiguration new];
    self.config.program = BP_MASTER;
    self.config.testBundlePath = testBundlePath;
    self.config.appBundlePath = hostApplicationPath;
    self.config.stuckTimeout = @30;
    self.config.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    self.config.runtime = @BP_DEFAULT_RUNTIME;
    self.config.repeatTestsCount = @1;
    self.config.errorRetriesCount = @0;
    self.config.failureTolerance = @0;
    self.config.deviceType = @BP_DEFAULT_DEVICE_TYPE;
    self.config.plainOutput = NO;
    self.config.jsonOutput = NO;
    self.config.headlessMode = NO;
    self.config.junitOutput = NO;
    NSString *path = @"testScheme.xcscheme";
    self.config.schemePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:path];
}

- (void)tearDown {
    self.config.testCasesToSkip = @[];
    [super tearDown];
}

- (void)testPackingWithXctFileContainingSkipTestIdentifiers {
    self.config.testBundlePath = [BPTestHelper sampleAppBalancingTestsBundlePath];
    self.config.numSims = @2;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    app.testBundles[0].skipTestIdentifiers = @[@"BPSampleAppTests/testCase000", @"BPSampleAppTests/testCase001"];

    XCTAssert(app != nil);
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

- (void)testPacking {
    NSArray *want, *got;
    NSArray *allTests;
    NSArray<BPXCTestFile *> *bundles;

    allTests = [[NSMutableArray alloc] init];
    self.config.testBundlePath = nil;
    BPApp *app = [BPApp appWithConfig:self.config withError:nil];
    XCTAssert(app != nil);
    // Make sure we have the test bundles we expect. If we add more, this will pop but that's okay. Just add
    // the additional test bundles here.
    want = @[ @"BPAppNegativeTests.xctest",
              @"BPSampleAppCrashingTests.xctest",
              @"BPSampleAppFatalErrorTests.xctest",
              @"BPSampleAppHangingTests.xctest",
              @"BPSampleAppTests.xctest"];
    NSMutableArray *tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *bundle in app.testBundles) {
        [tests addObject:[bundle.testBundlePath lastPathComponent]];
    }
    got = [tests sortedArrayUsingSelector:@selector(compare:)];
    XCTAssert([want isEqualToArray:got]);

    // Let's gather all the tests and always make sure we get them all
    tests = [[NSMutableArray alloc] init];
    for (BPXCTestFile *testFile in app.testBundles) {
        [tests addObjectsFromArray:[testFile allTestCases]];
    }
    allTests = [tests sortedArrayUsingSelector:@selector(compare:)];
    // Make sure we don't split when we don't want to
    self.config.numSims = @4;
    self.config.noSplit = @[@"BPSampleAppTests"];
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];// withNoSplitList:@[@"BPSampleAppTests"] intoBundles:4 andError:nil];
    // When we prevent BPSampleTests from splitting, BPSampleAppFatalErrorTests gets split in two
    want = [[want arrayByAddingObject:@"BPSampleAppFatalErrorTests"] sortedArrayUsingSelector:@selector(compare:)];
    XCTAssert(bundles.count == app.testBundles.count + 1);

    XCTAssert([bundles[0].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[1].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[2].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[3].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[4].skipTestIdentifiers count] == 2);
    XCTAssert([bundles[5].skipTestIdentifiers count] == 3);

    self.config.numSims = @4;
    self.config.noSplit = nil;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    // 4 unbreakable bundles (too few tests) and the big one broken into 4 bundles
    XCTAssert(bundles.count == 8);
    // All we want to test is that we have full coverage
    XCTAssert([bundles[0].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[1].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[2].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[3].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[4].skipTestIdentifiers count] == 148);
    XCTAssert([bundles[5].skipTestIdentifiers count] == 148);
    XCTAssert([bundles[6].skipTestIdentifiers count] == 148);
    XCTAssert([bundles[7].skipTestIdentifiers count] == 159);

    self.config.numSims = @1;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];
    // If we pack into just one bundle, we can't have less bundles than the total number of .xctest files.
    XCTAssert(bundles.count == app.testBundles.count);

    self.config.numSims = @16;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];

    XCTAssert([bundles[0].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[1].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[2].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[3].skipTestIdentifiers count] == 0);
    XCTAssert([bundles[4].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[5].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[6].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[7].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[8].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[9].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[10].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[11].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[12].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[13].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[14].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[15].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[16].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[17].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[18].skipTestIdentifiers count] == 188);
    XCTAssert([bundles[19].skipTestIdentifiers count] == 195);

    NSMutableArray *toRun = [[NSMutableArray alloc] init];
    for (long i = 1; i <= 20; i++) {
        [toRun addObject:[NSString stringWithFormat:@"BPSampleAppTests/testCase%03ld", i]];
    }
    self.config.numSims = @4;
    self.config.testCasesToRun = toRun;
    bundles = [BPPacker packTests:app.testBundles configuration:self.config andError:nil];

    XCTAssertEqual(bundles.count, 4);
    for (BPXCTestFile *bundle in bundles) {
        XCTAssertEqual(bundle.skipTestIdentifiers.count, 196);
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
