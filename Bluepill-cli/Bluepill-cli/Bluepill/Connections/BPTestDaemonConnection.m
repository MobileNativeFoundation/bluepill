//
//  BPTestDaemonConnection.m
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "BPTestDaemonConnection.h"
#import "BPUtils.h"
#import "BPConstants.h"

// XCTest framework
#import "XCTestManager_IDEInterface-Protocol.h"
#import "XCTestManager_TestsInterface-Protocol.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCTestManager_DaemonConnectionInterface-Protocol.h"
#import "XCTestDriverInterface-Protocol.h"

// DTX framework
#import "DTXConnection.h"
#import "DTXProxyChannel.h"
#import "DTXRemoteInvocationReceipt.h"
#import "DTXTransport.h"
#import "DTXSocketTransport.h"

// sys
#import <sys/socket.h>
#import <sys/un.h>

// runtime
#import <objc/runtime.h>

static const NSString * const testManagerEnv = @"TESTMANAGERD_SIM_SOCK";

@interface BPTestDaemonConnection()<XCTestManager_IDEInterface>
@property (nonatomic, strong) id<XCTestManager_IDEInterface> interface;
@property (nonatomic, assign) BOOL connected;
@end

@implementation BPTestDaemonConnection

- (instancetype)initWithDevice:(BPSimulator *)simulator andInterface:(id<XCTestManager_IDEInterface>)interface {
    self = [super init];
    if (self) {
        self.simulator = simulator;
        self.interface = interface;
    }
    return self;
}

- (void)connectWithTimeout:(NSTimeInterval)timeout {
    [self connect];
    // Pool connection status till it passes.
    [BPUtils runWithTimeOut:timeout until:^BOOL{
        return self.connected;
    }];
    if (!self.connected) {
        [BPUtils printInfo:ERROR withString:@"Timeout establishing a control session!"];
    }
}

- (void)connect {
    DTXTransport *transport = [self connectTransport];
    DTXConnection *connection = [[objc_lookUpClass("DTXConnection") alloc] initWithTransport:transport];
    [connection registerDisconnectHandler:^{
        [BPUtils printInfo:INFO withString:@"Daemon connection Disconnected."];
    }];
    [connection resume];

    DTXProxyChannel *channel = [connection
                                makeProxyChannelWithRemoteInterface:@protocol(XCTestManager_DaemonConnectionInterface)
                                exportedInterface:@protocol(XCTestManager_IDEInterface)];

    [channel setExportedObject:self queue:dispatch_get_main_queue()];
    id<XCTestManager_DaemonConnectionInterface> daemonProxy = (id<XCTestManager_DaemonConnectionInterface>)channel.remoteObjectProxy;
    DTXRemoteInvocationReceipt *receipt = [daemonProxy _IDE_initiateControlSessionForTestProcessID:@(self.testRunnerPid) protocolVersion:@(BP_DAEMON_PROTOCOL_VERSION)];
    [receipt handleCompletion:^(NSNumber *version, NSError *error) {
        if (error) {
            [BPUtils printInfo:ERROR withString:@"Error with daemon connection: %@", [error localizedDescription]];
            return;
        }
        NSInteger daemonProtocolVersion = version.integerValue;
        [BPUtils printInfo:INFO withString:@"Daemon ready to execute test plan (protocol version %ld)", (long)daemonProtocolVersion];
        self.connected = YES;
    }];
}

- (int)testManagerSocket {
    int socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    NSString *socketString = [self.simulator.device getenv:testManagerEnv error:nil];
    const char *socketPath = socketString.UTF8String;

    struct sockaddr_un remote;
    remote.sun_family = AF_UNIX;
    strncpy(remote.sun_path, socketPath, 104);
    socklen_t length = (socklen_t)(strnlen(remote.sun_path, 1024) + sizeof(remote.sun_family) + sizeof(remote.sun_len));
    if (connect(socketFD, (struct sockaddr *)&remote, length) == -1) {
        [BPUtils printInfo:ERROR withString:@"ERROR connecting socket"];
    }
    return socketFD;
}

- (DTXTransport *)connectTransport {
    int socketFD = [self testManagerSocket];
    DTXTransport *transport = [[objc_lookUpClass("DTXSocketTransport") alloc] initWithConnectedSocket:socketFD disconnectAction:^{
        [BPUtils printInfo:INFO withString:@"DTXSocketTransport disconnected"];
    }];
    return transport;
}

#pragma mark - XCTestManager_IDEInterface protocol

#pragma mark Process Launch Delegation

- (id)_XCT_launchProcessWithPath:(NSString *)path bundleID:(NSString *)bundleID arguments:(NSArray *)arguments environmentVariables:(NSDictionary *)environment {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_launchProcessWithPath: %@, bundleID: %@, arguments: %@, environmentVariables: %@", path, bundleID, arguments, environment];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_getProgressForLaunch:(id)token {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_getProgressForLaunch token: %@", token];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_terminateProcess:(id)token {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_terminateProcess token: %@", token];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_didBeginExecutingTestPlan {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didBeginExecutingTestPlan"];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_didFinishExecutingTestPlan {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didFinishExecutingTestPlan"];
    return [self handleUnimplementedXCTRequest:_cmd];
}

#pragma mark iOS 10.x
- (id)_XCT_handleCrashReportData:(NSData *)arg1 fromFileWithName:(NSString *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_handleCrashReportData: %@, fromFileWithName: %@", arg1, arg2];
    return nil;
}

- (id)_XCT_didBeginInitializingForUITesting {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didBeginInitializingForUITesting"];
    return nil;
}

- (id)_XCT_initializationForUITestingDidFailWithError:(NSError *)error {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_initializationForUITestingDidFailWithError : %@", error];
    return nil;
}

- (id)_XCT_testBundleReadyWithProtocolVersion:(NSNumber *)protocolVersion minimumVersion:(NSNumber *)minimumVersion {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testBundleReadyWithProtocolVersion : %@, minimumVersion: %@", protocolVersion, minimumVersion];
    return nil;
}

#pragma mark Test Suite Progress

- (id)_XCT_testSuite:(NSString *)tests didStartAt:(NSString *)time {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testSuite : %@, didStartAt: %@", tests, time];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseDidStartForTestClass:(NSString *)testClass method:(NSString *)method {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidStartForTestClass : %@, method: %@", testClass, method];
    return nil;
}

- (id)_XCT_testCaseDidFailForTestClass:(NSString *)testClass method:(NSString *)method withMessage:(NSString *)message file:(NSString *)file line:(NSNumber *)line {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidFailForTestClass : %@, method: %@, withMessage: %@, file: %@, line: %@", testClass, method, message, file, line];
    return nil;
}

- (id)_XCT_logDebugMessage:(NSString *)debugMessage {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_logDebugMessage: %@", debugMessage];
    return nil;
}

- (id)_XCT_logMessage:(NSString *)message {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_logMessage: %@", message];
    return nil;
}

- (id)_XCT_testCaseDidFinishForTestClass:(NSString *)testClass method:(NSString *)method withStatus:(NSString *)statusString duration:(NSNumber *)duration {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidFinishForTestClass: %@, method: %@, withStatus: %@, duration: %@", testClass, method, statusString, duration];
    return nil;
}

- (id)_XCT_testSuite:(NSString *)arg1 didFinishAt:(NSString *)arg2 runCount:(NSNumber *)arg3 withFailures:(NSNumber *)arg4 unexpected:(NSNumber *)arg5 testDuration:(NSNumber *)arg6 totalDuration:(NSNumber *)arg7 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testSuite: %@, didFinishAt: %@, runCount: %@, withFailures: %@, unexpected: %@, testDuration: %@, totalDuration: %@", arg1, arg2, arg3, arg4, arg5, arg6, arg7];
    return nil;
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 didFinishActivity:(XCActivityRecord *)arg3 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCase: %@, method: %@, didFinishActivity: %@", arg1, arg2, arg3];
    return nil;
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 willStartActivity:(XCActivityRecord *)arg3 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCase: %@, method: %@, willStartActivity: %@", arg1, arg2, arg3];
    return nil;
}

#pragma mark - Unimplemented

- (id)_XCT_nativeFocusItemDidChangeAtTime:(NSNumber *)arg1 parameterSnapshot:(XCElementSnapshot *)arg2 applicationSnapshot:(XCElementSnapshot *)arg3 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedEventNames:(NSArray *)arg1 timestamp:(NSNumber *)arg2 duration:(NSNumber *)arg3 startLocation:(NSDictionary *)arg4 startElementSnapshot:(XCElementSnapshot *)arg5 startApplicationSnapshot:(XCElementSnapshot *)arg6 endLocation:(NSDictionary *)arg7 endElementSnapshot:(XCElementSnapshot *)arg8 endApplicationSnapshot:(XCElementSnapshot *)arg9 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedOrientationChange:(NSString *)arg1 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedFirstResponderChangedWithApplicationSnapshot:(XCElementSnapshot *)arg1 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_exchangeCurrentProtocolVersion:(NSNumber *)arg1 minimumVersion:(NSNumber *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedKeyEventsWithApplicationSnapshot:(XCElementSnapshot *)arg1 characters:(NSString *)arg2 charactersIgnoringModifiers:(NSString *)arg3 modifierFlags:(NSNumber *)arg4 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedEventNames:(NSArray *)arg1 duration:(NSNumber *)arg2 startLocation:(NSDictionary *)arg3 startElementSnapshot:(XCElementSnapshot *)arg4 startApplicationSnapshot:(XCElementSnapshot *)arg5 endLocation:(NSDictionary *)arg6 endElementSnapshot:(XCElementSnapshot *)arg7 endApplicationSnapshot:(XCElementSnapshot *)arg8 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedKeyEventsWithCharacters:(NSString *)arg1 charactersIgnoringModifiers:(NSString *)arg2 modifierFlags:(NSNumber *)arg3 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedEventNames:(NSArray *)arg1 duration:(NSNumber *)arg2 startElement:(XCAccessibilityElement *)arg3 startApplicationSnapshot:(XCElementSnapshot *)arg4 endElement:(XCAccessibilityElement *)arg5 endApplicationSnapshot:(XCElementSnapshot *)arg6 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedEvent:(NSString *)arg1 targetElementID:(NSDictionary *)arg2 applicationSnapshot:(XCElementSnapshot *)arg3 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_recordedEvent:(NSString *)arg1 forElement:(NSString *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testMethod:(NSString *)arg1 ofClass:(NSString *)arg2 didMeasureMetric:(NSDictionary *)arg3 file:(NSString *)arg4 line:(NSNumber *)arg5 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 didStallOnMainThreadInFile:(NSString *)arg3 line:(NSNumber *)arg4 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testMethod:(NSString *)arg1 ofClass:(NSString *)arg2 didMeasureValues:(NSArray *)arg3 forPerformanceMetricID:(NSString *)arg4 name:(NSString *)arg5 withUnits:(NSString *)arg6 baselineName:(NSString *)arg7 baselineAverage:(NSNumber *)arg8 maxPercentRegression:(NSNumber *)arg9 maxPercentRelativeStandardDeviation:(NSNumber *)arg10 file:(NSString *)arg11 line:(NSNumber *)arg12 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testBundleReady {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (NSString *)unknownMessageForSelector:(SEL)aSelector
{
    return [NSString stringWithFormat:@"Received call for unhandled method (%@). Probably you should have a look at _IDETestManagerAPIMediator in IDEFoundation.framework and implement it. Good luck!", NSStringFromSelector(aSelector)];
}

// This will add more logs when unimplemented method from XCTestManager_IDEInterface protocol is called
- (id)handleUnimplementedXCTRequest:(SEL)aSelector {
    [BPUtils printInfo:DEBUGINFO withString:@"TMD: unimplemented: %s", sel_getName(aSelector)];
    NSAssert(nil, [self unknownMessageForSelector:_cmd]);
    return nil;
}

@end
