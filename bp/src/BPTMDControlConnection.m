//
//  BPTMDControlConnection.m
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "BPTMDControlConnection.h"
#import "BPUtils.h"
#import "BPConstants.h"

// XCTAutomationSupport framework
#import "PrivateHeaders/XCTAutomationSupport/XCElementSnapshot.h"
//#import "PrivateHeaders/XCTAutomationSupport/XCTCapabilities.h"
//#import "PrivateHeaders/XCTAutomationSupport/XCTCapabilitiesBuilder.h"

// XCTest framework
#import "PrivateHeaders/XCTest/XCActivityRecord.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToRunner-Protocol.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_IDEToDaemon-Protocol.h"
#import "PrivateHeaders/XCTest/XCTMessagingChannel_DaemonToIDE-Protocol.h"

// DTX framework
#import "PrivateHeaders/DTXConnectionServices/DTXConnection.h"
#import "PrivateHeaders/XCTest/DTXConnection-XCTestAdditions.h"
#import "PrivateHeaders/DTXConnectionServices/DTXProxyChannel.h"
#import "PrivateHeaders/XCTest/DTXProxyChannel-XCTestAdditions.h"
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

@interface BPTMDControlConnection()<XCTMessagingChannel_DaemonToIDE>
@property (nonatomic, assign) BOOL connected;
@end

@implementation BPTMDControlConnection

- (instancetype)initWithSimDevice:(SimDevice *)device andTestRunnerPID: (pid_t) pid {
    self = [super init];
    if (self) {
        self.device = device;
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
    [BPUtils printInfo:DEBUGINFO withString:@"connected to testmanagerd"];
}

- (void)connect {
    DTXConnection *connection = connectToTestManager(self.device);
    [connection registerDisconnectHandler:^{
        [BPUtils printInfo:INFO withString:@"Daemon connection Disconnected."];
    }];
    [connection resume];

    DTXProxyChannel *channel = [connection
                                xct_makeProxyChannelWithRemoteInterface:@protocol(XCTMessagingChannel_IDEToDaemon)
                                exportedInterface:@protocol(XCTMessagingChannel_DaemonToIDE)];
    [channel xct_setAllowedClassesForTestingProtocols];
    [channel setExportedObject:self queue:dispatch_get_main_queue()];
    id<XCTMessagingChannel_IDEToDaemon> daemonProxy = (id<XCTMessagingChannel_IDEToDaemon>)channel.remoteObjectProxy;
    DTXRemoteInvocationReceipt *receipt = [daemonProxy _IDE_initiateControlSessionForTestProcessID:@(self.testRunnerPid) protocolVersion:@(BP_TM_PROTOCOL_VERSION)];
    
    [receipt handleCompletion:^(NSNumber *version, NSError *error) {
        self.connected = TRUE;
        if (error) {
            [BPUtils printInfo:ERROR withString:@"Error with daemon connection: %@", error];
            return;
        }
        NSInteger daemonProtocolVersion = version.integerValue;
        [BPUtils printInfo:INFO withString:@"Test manager daemon control session started (%ld)", (long)daemonProtocolVersion];
    }];
}

DTXConnection* connectToTestManager(SimDevice *device) {
    if (!device) return nil;
    
    NSString *testManagerSocketPath = [device getenv:@"TESTMANAGERD_SIM_SOCK" error:nil];
    const char *socketPath = testManagerSocketPath.UTF8String;

    // struct sockaddr_un below only has 104 bytes for sun_path field so
    // we fail early here
    if (strnlen(socketPath, 1024) >= 104) {
        [BPUtils printInfo:ERROR withString:@"socket path too long (103 max): %s", socketPath];
        return nil;
    }
    int socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (socketFD == -1) {
        [BPUtils printInfo:ERROR withString:@"socket(): %s", strerror(errno)];
        return nil;
    }
    struct sockaddr_un remote;
    remote.sun_family = AF_UNIX;
    strncpy(remote.sun_path, socketPath, 104);
    socklen_t length = (socklen_t)(strnlen(remote.sun_path, 1024) + sizeof(remote.sun_family) + sizeof(remote.sun_len));
    if (connect(socketFD, (struct sockaddr *)&remote, length) == -1) {
        [BPUtils printInfo:ERROR withString:@"ERROR connecting socket"];
        close(socketFD);
    }
    DTXTransport *transport = [[objc_lookUpClass("DTXSocketTransport") alloc] initWithConnectedSocket:socketFD disconnectAction:^{
        [BPUtils printInfo:INFO withString:@"DTXSocketTransport disconnected"];
    }];
    return [[objc_lookUpClass("DTXConnection") alloc] initWithTransport:transport];
}

#pragma mark XCTMessagingChannel_DaemonToIDE methods

- (id)_XCT_logDebugMessage:(NSString *)arg1 {
    [BPUtils printInfo:DEBUGINFO withString:@"_XCT_logDebugMessage is unimplemented"];
    return nil;
}

- (id)_XCT_reportSelfDiagnosisIssue:(NSString *)arg1 description:(NSString *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"_XCT_reportSelfDiagnosisIssue is unimplemented"];
    return nil;
}

- (id)_XCT_handleCrashReportData:(NSData *)arg1 fromFileWithName:(NSString *)arg2 {
    [BPUtils printInfo:DEBUGINFO withString:@"_XCT_handleCrashReportData is unimplemented"];
    return nil;
}

#pragma mark Handy methods for unimplemented stuff

- (NSString *)unknownMessageForSelector:(SEL)aSelector
{
    return [NSString stringWithFormat:@"Received call for unhandled method (%@). Probably you should have a look at _IDETestManagerAPIMediator in IDEFoundation.framework and implement it. Good luck!", NSStringFromSelector(aSelector)];
}

// This will add more logs when unimplemented method from XCTMessagingChannel_DaemonToIDE protocol is called
- (id)handleUnimplementedXCTRequest:(SEL)aSelector {
    [BPUtils printInfo:DEBUGINFO withString:@"TMD: unimplemented: %s", sel_getName(aSelector)];
    NSAssert(nil, [self unknownMessageForSelector:_cmd]);
    return nil;
}

@end
