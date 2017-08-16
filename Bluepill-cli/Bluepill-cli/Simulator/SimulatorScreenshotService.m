//
//  SimulatorScreenshotService.m
//  Bluepill-cli
//
//  Created by Szeremeta Adam on 16.08.2017.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "SimulatorScreenshotService.h"
#import "SimDeviceFramebufferService.h"
#import "BPUtils.h"

#import <objc/runtime.h>

@interface SimulatorScreenshotService()

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) SimDeviceFramebufferService *frameBufferService;

@end

@implementation SimulatorScreenshotService

+ (instancetype)simulatorScreenshotServiceWithConfiguration:(BPConfiguration *)config forDevice:(SimDevice *)device {
    SimulatorScreenshotService *service = [[self alloc] init];
    service.config = config;

    if ([service meetsPreconditionsForConnectingToDevice:device]) {
        service.frameBufferService = [service createMainScreenServiceForDevice:device];
    }

    return service;
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

#pragma mark Private Methods

- (BOOL)meetsPreconditionsForConnectingToDevice:(SimDevice *)device {
    if ([device.stateString isEqualToString:@"Booted"] || [device.stateString isEqualToString:@"Shutdown"]) {
        return YES;
    }

    [BPUtils printInfo:ERROR withString:@"ScreenshotService can be created for device: %@. Device has wrong state: %@", device.UDID, device.stateString];
    return NO;
}

- (SimDeviceFramebufferService *)createMainScreenServiceForDevice:(SimDevice *)device {
    NSError *error = nil;
    SimDeviceFramebufferService *service = [objc_lookUpClass("SimDeviceFramebufferService")
                                            mainScreenFramebufferServiceForDevice: device
                                            error: &error];
    if (!service) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"Failed to create FrameBufferService for device: %@, error: %@", [device UDID], [error localizedDescription]]];
    }
    return service;
}

/*+ (instancetype)framebufferWithService:(SimDeviceFramebufferService *)framebufferService configuration:(FBFramebufferConfiguration *)configuration simulator:(FBSimulator *)simulator
{
    dispatch_queue_t queue = self.createClientQueue;
    id<FBControlCoreLogger> logger = [self loggerForSimulator:simulator queue:queue];

    if (FBControlCoreGlobalConfiguration.isXcode8OrGreater) {
        FBFramebufferSurface *surface = [FBFramebufferSurface mainScreenSurfaceForFramebufferService:framebufferService];
        FBFramebufferFrameGenerator *frameGenerator = [FBFramebufferIOSurfaceFrameGenerator
                                                       generatorWithRenderable:surface
                                                       scale:configuration.scaleValue
                                                       queue:queue
                                                       logger:logger];

        return [[FBFramebuffer_IOSurface alloc] initWithConfiguration:configuration eventSink:simulator.eventSink frameGenerator:frameGenerator surface:surface logger:logger];
    }
    FBFramebufferBackingStoreFrameGenerator *frameGenerator = [FBFramebufferBackingStoreFrameGenerator generatorWithFramebufferService:framebufferService scale:configuration.scaleValue queue:queue logger:logger];
    return [[FBFramebuffer_FramebufferService alloc] initWithConfiguration:configuration eventSink:simulator.eventSink frameGenerator:frameGenerator surface:nil logger:logger];
}*/

@end


//[BPUtils printInfo:INFO withString:@"Main screen service created for device: %@", [ __self.device UDID]];
//[BPUtils printInfo:INFO withString:@"Device state: %@", __self.device.stateString];
//[BPUtils printInfo:INFO withString:@"Lookup: %@", objc_lookUpClass("SimDeviceFramebufferService")];
