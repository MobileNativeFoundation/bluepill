//
//  SimulatorScreenshotService.m
//  Bluepill-cli
//
//  Created by Szeremeta Adam on 16.08.2017.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "SimulatorScreenshotService.h"
#import "SimDeviceFramebufferService.h"
#import "SimDeviceFramebufferBackingStore.h"
#import "BPUtils.h"
#import "BPWaitTimer.h"

#import <objc/runtime.h>

static const NSTimeInterval BPSimulatorFramebufferFrameTimeInterval = 0.033;

@interface SimulatorScreenshotService() <SimDisplayDamageRectangleDelegate, SimDisplayIOSurfaceRenderableDelegate, SimDeviceIOPortConsumer>

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) SimDeviceFramebufferService *frameBufferService;
@property (nonatomic, strong) dispatch_queue_t frameBufferQueue;
@property (nonatomic, strong) NSTimer *frameTimer;

@end

@implementation SimulatorScreenshotService

- (instancetype)initWithConfiguration:(BPConfiguration *)config forDevice:(SimDevice *)device {
    self = [super init];
    if (self) {
        self.config = config;
        self.device = device;

        if ([self meetsPreconditionsForConnectingToDevice:device]) {
            self.frameBufferService = [self createMainScreenServiceForDevice:device];
        }
    }

    return self;
}

- (CGImageRef)screenshot {

    //to do

    return nil;
}

- (BOOL)saveScreenshotForFailedTestWithName:(NSString *)name {
    [BPUtils printInfo:INFO withString:@"Saving screenshot for failed test: %@", name];


    //to do

    return YES;
}

- (void)startService {
    [BPUtils printInfo:INFO withString:@"Starting SimulatorScreenshotService for device: %@", self.device.UDID.UUIDString];

    self.frameBufferQueue = dispatch_queue_create("com.linkedin.bluepill.SimulatorScreenshotService", DISPATCH_QUEUE_SERIAL);

    [self.frameBufferService registerClient:self onQueue:self.frameBufferQueue];
    [self.frameBufferService resume];
}

- (void)stopService {
    [BPUtils printInfo:INFO withString:@"Stopping SimulatorScreenshotService for device: %@", self.device.UDID.UUIDString];

    [self.frameTimer invalidate];
    [self.frameBufferService unregisterClient:self];
}

#pragma mark Private Methods

- (BOOL)meetsPreconditionsForConnectingToDevice:(SimDevice *)device {
    if ([device.stateString isEqualToString:@"Booted"] || [device.stateString isEqualToString:@"Shutdown"]) {
        return YES;
    }

    [BPUtils printInfo:ERROR withString:@"ScreenshotService can't be created for device: %@. Device has wrong state: %@", self.device.UDID.UUIDString, device.stateString];
    return NO;
}

- (SimDeviceFramebufferService *)createMainScreenServiceForDevice:(SimDevice *)device {
    NSError *error = nil;
    SimDeviceFramebufferService *service = [objc_lookUpClass("SimDeviceFramebufferService")
                                            mainScreenFramebufferServiceForDevice: device
                                            error: &error];
    if (!service) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"Failed to create FrameBufferService for device: %@, error: %@", self.device.UDID.UUIDString, [error localizedDescription]]];
    }
    return service;
}

- (void)generateScreenshot {


}

#pragma mark SimDisplayDamageRectangleDelegate, SimDisplayIOSurfaceRenderableDelegate, SimDeviceIOPortConsumer

- (void)setIOSurface:(IOSurfaceRef)surface {
    [BPUtils printInfo:INFO withString:@"Surface changed: set %@", surface];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.frameTimer invalidate];

        __weak typeof(self) __self = self;
        self.frameTimer = [NSTimer scheduledTimerWithTimeInterval:BPSimulatorFramebufferFrameTimeInterval repeats:YES block:^(NSTimer * _Nonnull timer) {
            [__self generateScreenshot];
        }];
    });
}







- (void)framebufferService:(SimDeviceFramebufferService *)service didUpdateRegion:(CGRect)region ofBackingStore:(SimDeviceFramebufferBackingStore *)backingStore
{
    [BPUtils printInfo:INFO withString:@"Surface changed region: %@", region];

}

- (void)framebufferService:(SimDeviceFramebufferService *)service didRotateToAngle:(double)angle
{
    [BPUtils printInfo:INFO withString:@"Surface changed: angle %@", angle];

}

- (void)framebufferService:(SimDeviceFramebufferService *)service didFailWithError:(NSError *)error
{
    [BPUtils printInfo:INFO withString:@"Surface changed fail: %@", error];

}

- (void)didChangeIOSurface:(nullable id)unknown
{
    [BPUtils printInfo:INFO withString:@"Surface changed: %@", unknown];
}

- (void)didReceiveDamageRect:(CGRect)rect
{
    [BPUtils printInfo:INFO withString:@"Surface changed: damage %@", rect];

}

- (NSString *)consumerIdentifier {
    return NSStringFromClass(self.class);
}

- (NSString *)consumerUUID {
    return NSUUID.UUID.UUIDString;
}




@end


//[BPUtils printInfo:INFO withString:@"Main screen service created for device: %@", [ __self.device UDID]];
//[BPUtils printInfo:INFO withString:@"Device state: %@", __self.device.stateString];
//[BPUtils printInfo:INFO withString:@"Lookup: %@", objc_lookUpClass("SimDeviceFramebufferService")];
