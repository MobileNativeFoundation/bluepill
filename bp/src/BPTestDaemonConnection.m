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

// XCTAutomationSupport framework
#import "PrivateHeaders/XCTAutomationSupport/XCElementSnapshot.h"

// XCTest framework
#import "PrivateHeaders/XCTest/XCActivityRecord.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToRunner-Protocol.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToDaemon-Protocol.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_DaemonToIDE-Protocol.h"

// DTX framework
#import "PrivateHeaders/DTXConnectionServices/DTXConnection.h"
#import "PrivateHeaders/DTXConnectionServices/DTXProxyChannel.h"
#import "PrivateHeaders/DTXConnectionServices/DTXRemoteInvocationReceipt.h"
#import "PrivateHeaders/DTXConnectionServices/DTXTransport.h"
#import "PrivateHeaders/DTXConnectionServices/DTXSocketTransport.h"

// CoreSimulator
#import "PrivateHeaders/CoreSimulator/SimDevice.h"

// sys
#import <sys/socket.h>
#import <sys/un.h>

// runtime
#import <objc/runtime.h>

static const NSString * const testManagerEnv = @"TESTMANAGERD_SIM_SOCK";

@interface BPTestDaemonConnection()<XCTMessagingChannel_DaemonToIDE>
@property (nonatomic, assign) BOOL connected;
@end

@implementation BPTestDaemonConnection

- (instancetype)initWithDevice:(BPSimulator *)simulator andTestRunnerPID: (pid_t) pid {
    self = [super init];
    if (self) {
        self.simulator = simulator;
        self.testRunnerPid = pid;
    }
    return self;
}

- (void)connectWithTimeout:(NSTimeInterval)timeout {
    [self connect];
    // Poll connection status till it passes.
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
                                makeProxyChannelWithRemoteInterface:@protocol(XCTMessagingChannel_IDEToDaemon)
                                exportedInterface:@protocol(XCTMessagingChannel_DaemonToIDE)];

    [channel setExportedObject:self queue:dispatch_get_main_queue()];
    id<XCTMessagingChannel_IDEToDaemon> daemonProxy = (id<XCTMessagingChannel_IDEToDaemon>)channel.remoteObjectProxy;
    DTXRemoteInvocationReceipt *receipt = [daemonProxy _IDE_initiateControlSessionForTestProcessID:@(self.testRunnerPid)];
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

// TODO: Xcode_12.5 ???
- (id)_XCT_logMessage:(NSString *)message {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_logMessage: %@", message];
    return nil;
}

#pragma mark - XCTMessagingRole_CrashReporting protocol
// TODO: Xcode_12.5 XCTMessagingRole_CrashReporting belongs to XCTMessagingChannel_DaemonToIDE

- (id)_XCT_handleCrashReportData:(NSData *)arg1 fromFileWithName:(NSString *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_handleCrashReportData: %@, fromFileWithName: %@", arg1, arg2];
    return nil;
}

#pragma mark - XCTMessagingChannel_RunnerToIDE protocol

#pragma mark - XCTMessagingRole_UIAutomation protocol

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

- (id)_XCT_didBeginInitializingForUITesting {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didBeginInitializingForUITesting"];
    return nil;
}

- (id)_XCT_initializationForUITestingDidFailWithError:(NSError *__strong)errPtr {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_initializationForUITestingDidFailWithError : %@", errPtr];
    return nil;
}

#pragma mark - XCTMessagingRole_TestReporting protocol

- (id)_XCT_didBeginExecutingTestPlan {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didBeginExecutingTestPlan"];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_didFinishExecutingTestPlan {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_didFinishExecutingTestPlan"];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testBundleReadyWithProtocolVersion:(NSNumber *)protocolVersion minimumVersion:(NSNumber *)minimumVersion {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testBundleReadyWithProtocolVersion : %@, minimumVersion: %@", protocolVersion, minimumVersion];
    return nil;
}

- (id)_XCT_testSuiteWithIdentifier:(XCTTestIdentifier *)testSuite didStartAt:(NSString *)time {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testSuiteWithIdentifier : %@, didStartAt: %@", testSuite, time];
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)testCase didFinishWithStatus:(NSString *)statusString duration:(NSNumber *)duration {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseWithIdentifier: %@, didFinishWithStatus: %@, duration: %@", testCase, statusString, duration];
    return nil;
}

- (id)_XCT_testSuiteWithIdentifier:(XCTTestIdentifier *)arg1 didFinishAt:(NSString *)arg2 runCount:(NSNumber *)arg3 skipCount:(NSNumber *)arg4 failureCount:(NSNumber *)arg5 expectedFailureCount:(NSNumber *)arg6 uncaughtExceptionCount:(NSNumber *)arg7 testDuration:(NSNumber *)arg8 totalDuration:(NSNumber *)arg9 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testSuite: %@, didFinishAt: %@, runCount: %@, skipCount: %@, failureCount: %@, expectedFailureCount: %@, uncaughtExceptionCount: %@, testDuration: %@, totalDuration: %@", arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9];
    return nil;
}

#pragma mark - XCTMessagingRole_TestReporting_Legacy protocol

- (id)_XCT_testCaseDidStartForTestClass:(NSString *)testClass method:(NSString *)method {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidStartForTestClass : %@, method: %@", testClass, method];
    return nil;
}

- (id)_XCT_testCaseDidFailForTestClass:(NSString *)testClass method:(NSString *)method withMessage:(NSString *)message file:(NSString *)file line:(NSNumber *)line {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidFailForTestClass : %@, method: %@, withMessage: %@, file: %@, line: %@", testClass, method, message, file, line];
    return nil;
}

- (id)_XCT_testCaseDidFinishForTestClass:(NSString *)testClass method:(NSString *)method withStatus:(NSString *)statusString duration:(NSNumber *)duration {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseDidFinishForTestClass: %@, method: %@, withStatus: %@, duration: %@", testClass, method, statusString, duration];
    return nil;
}

#pragma mark - XCTMessagingRole_DebugLogging protocol

- (id)_XCT_logDebugMessage:(NSString *)debugMessage {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_logDebugMessage: %@", debugMessage];
    return nil;
}

#pragma mark - XCTMessagingRole_ActivityReporting protocol

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 didFinishActivity:(XCActivityRecord *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseWithIdentifier: %@, didFinishActivity: %@", arg1, arg2];
    return nil;
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 willStartActivity:(XCActivityRecord *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCaseWithIdentifier: %@, willStartActivity: %@", arg1, arg2];
    return nil;
}

#pragma mark - XCTMessagingRole_ActivityReporting_Legacy protocol

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 didFinishActivity:(XCActivityRecord *)arg3 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCase: %@, method: %@, didFinishActivity: %@", arg1, arg2, arg3];
    return nil;
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 willStartActivity:(XCActivityRecord *)arg3 {
    [BPUtils printInfo:DEBUGINFO withString:@"BPTestDaemonConnection_XCT_testCase: %@, method: %@, willStartActivity: %@", arg1, arg2, arg3];
    return nil;
}

#pragma mark - Unimplemented

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 didStallOnMainThreadInFile:(NSString *)arg3 line:(NSNumber *)arg4 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWasSkippedForTestClass:(NSString *)arg1 method:(NSString *)arg2 withMessage:(NSString *)arg3 file:(NSString *)arg4 line:(NSNumber *)arg5 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testSuite:(NSString *)arg1 didFinishAt:(NSString *)arg2 runCount:(NSNumber *)arg3 skipCount:(NSNumber *)arg4 failureCount:(NSNumber *)arg5 expectedFailureCount:(NSNumber *)arg6 uncaughtExceptionCount:(NSNumber *)arg7 testDuration:(NSNumber *)arg8 totalDuration:(NSNumber *)arg9 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testSuite:(NSString *)arg1 didFinishAt:(NSString *)arg2 runCount:(NSNumber *)arg3 skipCount:(NSNumber *)arg4 failureCount:(NSNumber *)arg5 unexpectedFailureCount:(NSNumber *)arg6 testDuration:(NSNumber *)arg7 totalDuration:(NSNumber *)arg8 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testSuite:(NSString *)arg1 didFinishAt:(NSString *)arg2 runCount:(NSNumber *)arg3 withFailures:(NSNumber *)arg4 unexpected:(NSNumber *)arg5 testDuration:(NSNumber *)arg6 totalDuration:(NSNumber *)arg7 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testSuite:(NSString *)arg1 didStartAt:(NSString *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_didFailToBootstrapWithError:(NSError *)arg1 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_reportTestWithIdentifier:(XCTTestIdentifier *)arg1 didExceedExecutionTimeAllowance:(NSNumber *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseDidStartWithIdentifier:(XCTTestIdentifier *)arg1 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseDidStartWithIdentifier:(XCTTestIdentifier *)arg1 iteration:(NSNumber *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 didRecordExpectedFailure:(XCTExpectedFailure *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 didRecordIssue:(XCTIssue *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 didStallOnMainThreadInFile:(NSString *)arg2 line:(NSNumber *)arg3 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 wasSkippedWithMessage:(NSString *)arg2 sourceCodeContext:(XCTSourceCodeContext *)arg3 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testRunnerReadyWithCapabilities:(XCTCapabilities *)arg1 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testSuiteWithIdentifier:(XCTTestIdentifier *)arg1 didRecordIssue:(XCTIssue *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_reportSelfDiagnosisIssue:(NSString *)arg1 description:(NSString *)arg2 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testCaseWithIdentifier:(XCTTestIdentifier *)arg1 didMeasureMetric:(NSDictionary *)arg2 file:(NSString *)arg3 line:(NSNumber *)arg4 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testMethod:(NSString *)arg1 ofClass:(NSString *)arg2 didMeasureMetric:(NSDictionary *)arg3 file:(NSString *)arg4 line:(NSNumber *)arg5 {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (NSString *)unknownMessageForSelector:(SEL)aSelector
{
    return [NSString stringWithFormat:@"Received call for unhandled method (%@). Probably you should have a look at _IDETestManagerAPIMediator in IDEFoundation.framework and implement it. Good luck!", NSStringFromSelector(aSelector)];
}

// This will add more logs when unimplemented method from XCTMessagingChannel_RunnerToIDE protocol is called
- (id)handleUnimplementedXCTRequest:(SEL)aSelector {
    [BPUtils printInfo:DEBUGINFO withString:@"TMD: unimplemented: %s", sel_getName(aSelector)];
    NSAssert(nil, [self unknownMessageForSelector:_cmd]);
    return nil;
}

@end
