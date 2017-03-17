//
//  BPTestBundleConnection.m
//  Bluepill-cli
//
//  Created by Keqiu Hu on 2/7/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "BPTestBundleConnection.h"
#import "BPUtils.h"
#import "BPTestDaemonConnection.h"
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

#define BP_PROTOCOL_VERSION 22

static const NSString * const testManagerEnv = @"TESTMANAGERD_SIM_SOCK";

@interface BPTestBundleConnection()<XCTestManager_IDEInterface>

@property (atomic, nullable, strong) id<XCTestDriverInterface> testBundleProxy;
@property (atomic, nullable, strong, readwrite) DTXConnection *testBundleConnection;

@property (nonatomic, weak) id<BPTestBundleConnectionDelegate> interface;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, assign) pid_t appProcessPID;

@end

@implementation BPTestBundleConnection

- (instancetype)initWithDevice:(BPSimulator *)simulator andInterface:(id<BPTestBundleConnectionDelegate>)interface {
    self = [super init];
    if (self) {
        self.simulator = simulator;
        self.interface = interface;
        self.queue = dispatch_queue_create("com.linkedin.bluepill.connection.queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
    }
    return self;
}

- (void)connectWithTimeout:(NSTimeInterval)timeout {
    NSAssert(NSThread.isMainThread, @"-[%@ %@] should be called from the main thread", NSStringFromClass(self.class), NSStringFromSelector(_cmd));
    [self connect];

    // Pool connection status till it passes.
    [BPUtils runWithTimeOut:timeout until:^BOOL{
        return self.connected;
    }];
}

- (void)connect {
    dispatch_async(self.queue, ^{
        DTXTransport *transport = [self connectTransport];
        DTXConnection *connection = [[objc_lookUpClass("DTXConnection") alloc] initWithTransport:transport];
        [connection registerDisconnectHandler:^{
            NSLog(@"Bundle connection Disconnected.");
        }];
        [connection
         handleProxyRequestForInterface:@protocol(XCTestManager_IDEInterface)
         peerInterface:@protocol(XCTestDriverInterface)
         handler:^(DTXProxyChannel *channel){
             NSLog(@"Got proxy channel request from test bundle");
             [channel setExportedObject:self queue:dispatch_get_main_queue()];
             id<XCTestDriverInterface> interface = channel.remoteObjectProxy;
             self.testBundleProxy = interface;
         }];
        self.testBundleConnection = connection;
        NSLog(@"Resuming the test bundle connection");
        [self.testBundleConnection resume];

        dispatch_async(dispatch_get_main_queue(), ^{
            DTXProxyChannel *proxyChannel = [self.testBundleConnection
                                             makeProxyChannelWithRemoteInterface:@protocol(XCTestManager_DaemonConnectionInterface)
                                             exportedInterface:@protocol(XCTestManager_IDEInterface)];
            [proxyChannel setExportedObject:self queue:dispatch_get_main_queue()];
            id<XCTestManager_DaemonConnectionInterface> remoteProxy = (id<XCTestManager_DaemonConnectionInterface>) proxyChannel.remoteObjectProxy;


            NSLog(@"Starting test session with ID %@",self.config.sessionIdentifier.UUIDString);

            NSString *path = NSBundle.mainBundle.bundlePath;
            if (![path.pathExtension isEqualToString:@"app"]) {
                path = NSBundle.mainBundle.executablePath;
            }
            __block DTXRemoteInvocationReceipt *receipt = [remoteProxy
                                                           _IDE_initiateSessionWithIdentifier:self.config.sessionIdentifier
                                                           forClient:[self clientProcessUniqueIdentifier]
                                                           atPath:path
                                                           protocolVersion:@(22)];
            [receipt handleCompletion:^(NSNumber *version, NSError *error){
                if (error || !version) {
                    NSLog(@"ERRRORRRRR");
                    return;
                }
                NSLog(@"testmanagerd handled session request");
                [proxyChannel cancel];
            }];
        });
    });
}

- (void)startTestPlan {
    dispatch_async(self.queue, ^{
        NSLog(@"Start test plan!");
        [self.testBundleProxy _IDE_startExecutingTestPlanWithProtocolVersion:@(BP_PROTOCOL_VERSION)];
    });
}

- (NSString *)clientProcessUniqueIdentifier {
    static dispatch_once_t onceToken;
    static NSString *_clientProcessUniqueIdentifier;
    dispatch_once(&onceToken, ^{
        _clientProcessUniqueIdentifier = NSProcessInfo.processInfo.globallyUniqueString;
    });
    return _clientProcessUniqueIdentifier;
}

- (int)testManagerSocket {
    int socketFD = socket(AF_UNIX, SOCK_STREAM, 0);
    if (socketFD == -1) {
        NSLog(@"Error in creating socketFD");
    }
    NSString *socketString = [self.simulator.device getenv:testManagerEnv error:nil];
    const char *socketPath = socketString.UTF8String;

    if(![[NSFileManager new] fileExistsAtPath:socketString]) {
        NSLog(@"Does not exist - %@", socketString);
    }
    if(strnlen(socketPath, 1024) >= 104) {
        NSLog(@"TOO BIG - %@", socketString);
    }
    struct sockaddr_un remote;
    remote.sun_family = AF_UNIX;
    strncpy(remote.sun_path, socketPath, 104);
    socklen_t length = (socklen_t)(strnlen(remote.sun_path, 1024) + sizeof(remote.sun_family) + sizeof(remote.sun_len));
    if (connect(socketFD, (struct sockaddr *)&remote, length) == -1) {
        NSLog(@"ERROR!");
    }
    return socketFD;
}

- (DTXTransport *)connectTransport {
    if ([NSThread isMainThread]) {assert(NO);}
    int socketFD = [self testManagerSocket];
    if (socketFD == 1) {
        NSLog(@"Connection failed????");
    }
    DTXTransport *transport = [[objc_lookUpClass("DTXSocketTransport") alloc] initWithConnectedSocket:socketFD disconnectAction:^{
        NSLog(@"Connection failed");
        NSLog(@"end status: %d", transport.status);
    }];
    if (!transport) {
        NSLog(@"Transport creation failed");
    }
    return transport;
}

#pragma mark XCTestDriverInterface

- (id)_XCT_didBeginExecutingTestPlan {
//    NSLog(@"***Did begin executing test plan!");
    return nil;
}

- (id)_XCT_didFinishExecutingTestPlan {
//    NSLog(@"Did finish executing test plan");
    return nil;
}

- (id)_XCT_testBundleReadyWithProtocolVersion:(NSNumber *)protocolVersion minimumVersion:(NSNumber *)minimumVersion {
    self.connected = YES;
    NSLog(@"***Test Bundle is connected!");
    NSLog(@"***Protocol version is %@, minimum version is %@", protocolVersion, minimumVersion);
    return nil;
}

- (id)_XCT_didBeginInitializingForUITesting {
    NSLog(@"***Start initialization UI tests");
    return nil;
}

- (id)_XCT_initializationForUITestingDidFailWithError:(NSError *)error {
    return nil;
}

#pragma mark - XCTestManager_IDEInterface protocol

#pragma mark Process Launch Delegation

- (id)_XCT_launchProcessWithPath:(NSString *)path bundleID:(NSString *)bundleID arguments:(NSArray *)arguments environmentVariables:(NSDictionary *)environment
{
    NSDictionary *options = @{
                              @"arguments": arguments,
                              @"environment": environment,
                              };
    NSError *error;
    DTXRemoteInvocationReceipt *receipt = [objc_lookUpClass("DTXRemoteInvocationReceipt") new];
    [self.simulator.device installApplication:[NSURL fileURLWithPath:path] withOptions:@{kCFBundleIdentifier: bundleID} error:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    self.appProcessPID = [self.simulator.device launchApplicationWithID:bundleID options:options error:nil];
    self.bundleID = bundleID;
    if (error) {
        NSLog(@"%@", error);
    }
    id token = @(receipt.hash);
    [receipt invokeCompletionWithReturnValue:token error:error];
    return receipt;
}

- (id)_XCT_getProgressForLaunch:(id)token {
    NSLog(@"***Test process requested launch process status with token %@", token);
    DTXRemoteInvocationReceipt *receipt = [objc_lookUpClass("DTXRemoteInvocationReceipt") new];
    [receipt invokeCompletionWithReturnValue:@1 error:nil];
    return receipt;
}

- (id)_XCT_terminateProcess:(id)token {
    NSError *error;
    kill(self.appProcessPID, SIGKILL);
    DTXRemoteInvocationReceipt *receipt = [objc_lookUpClass("DTXRemoteInvocationReceipt") new];
    [receipt invokeCompletionWithReturnValue:token error:error];
    return receipt;
}

#pragma mark iOS 10.x
- (id)_XCT_handleCrashReportData:(NSData *)arg1 fromFileWithName:(NSString *)arg2 {
//    NSLog(@"*** Crash Data****");
    return nil;
}

#pragma mark Test Suite Progress

- (id)_XCT_testSuite:(NSString *)tests didStartAt:(NSString *)time {
//    NSLog(@"***Test start at time %@", time);
    return nil;
}

- (id)_XCT_testCaseDidStartForTestClass:(NSString *)testClass method:(NSString *)method {
//    NSLog(@"***Test did start for test class/method %@/%@", testClass, method);
    return nil;
}

- (id)_XCT_testCaseDidFailForTestClass:(NSString *)testClass method:(NSString *)method withMessage:(NSString *)message file:(NSString *)file line:(NSNumber *)line {
//    NSLog(@"***Test did fail for test class/method %@/%@/%@", testClass, method, message);
    return nil;
}

// This looks like tested application logs
- (id)_XCT_logDebugMessage:(NSString *)debugMessage {
    return nil;
}

- (id)_XCT_logMessage:(NSString *)message {
    return nil;
}

- (id)_XCT_testCaseDidFinishForTestClass:(NSString *)testClass method:(NSString *)method withStatus:(NSString *)statusString duration:(NSNumber *)duration {
//    NSLog(@"***Test did finish for test class/method %@/%@- %@", testClass, method, statusString);
    return nil;
}

- (id)_XCT_testSuite:(NSString *)arg1 didFinishAt:(NSString *)time runCount:(NSNumber *)count withFailures:(NSNumber *)failureCount unexpected:(NSNumber *)unexpectedCount testDuration:(NSNumber *)testDuration totalDuration:(NSNumber *)totalTime {
//    NSLog(@"*** testSuite did finish at %@, running %@ tests, with %@ failures, %@ unexpected, total time %@", time, count, failureCount, unexpectedCount, totalTime);
    return nil;
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 didFinishActivity:(XCActivityRecord *)arg3 {

    return nil;
}

- (id)_XCT_testCase:(NSString *)arg1 method:(NSString *)arg2 willStartActivity:(XCActivityRecord *)arg3 {
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
    NSLog(@"***Did stall on meinthread .. ");
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testMethod:(NSString *)arg1 ofClass:(NSString *)arg2 didMeasureValues:(NSArray *)arg3 forPerformanceMetricID:(NSString *)arg4 name:(NSString *)arg5 withUnits:(NSString *)arg6 baselineName:(NSString *)arg7 baselineAverage:(NSNumber *)arg8 maxPercentRegression:(NSNumber *)arg9 maxPercentRelativeStandardDeviation:(NSNumber *)arg10 file:(NSString *)arg11 line:(NSNumber *)arg12
{
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (id)_XCT_testBundleReady {
    return [self handleUnimplementedXCTRequest:_cmd];
}

- (NSString *)unknownMessageForSelector:(SEL)aSelector {
    return [NSString stringWithFormat:@"Received call for unhandled method (%@). Probably you should have a look at _IDETestManagerAPIMediator in IDEFoundation.framework and implement it. Good luck!", NSStringFromSelector(aSelector)];
}

// This will add more logs when unimplemented method from XCTestManager_IDEInterface protocol is called
- (id)handleUnimplementedXCTRequest:(SEL)aSelector {
    NSAssert(nil, [self unknownMessageForSelector:_cmd]);
    return nil;
}

@end
