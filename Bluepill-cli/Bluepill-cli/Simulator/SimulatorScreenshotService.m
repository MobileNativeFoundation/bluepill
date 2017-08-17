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
#import <CoreImage/CoreImage.h>

@interface SimulatorScreenshotService() <SimDisplayDamageRectangleDelegate, SimDisplayIOSurfaceRenderableDelegate, SimDeviceIOPortConsumer>

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) SimDeviceFramebufferService *frameBufferService;
@property (nonatomic, strong) dispatch_queue_t frameBufferQueue;
@property (nonatomic, assign) IOSurfaceRef ioSurface;

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
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *ciImage = [CIImage imageWithIOSurface:self.ioSurface];

    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    if (!cgImage) {
        [BPUtils printInfo:WARNING withString:@"Rendering simulator screenshot failed, returning null"];
        return NULL;
    }

    CFAutorelease(cgImage);
    return cgImage;
}

- (void)saveScreenshotForFailedTestWithName:(NSString *)name {
    [self saveScreenshotForFailedTestWithName:name suffix:1];
}

- (void)saveScreenshotForFailedTestWithName:(NSString *)name suffix:(int)suffix {
    NSString *outputFilePath = [NSString stringWithFormat:@"%@/%@_attempt_%d.jpeg", self.config.screenshotsDirectory, name, suffix];

    // Check if this file exists already
    if ([[NSFileManager defaultManager] fileExistsAtPath:outputFilePath]) {
        [self saveScreenshotForFailedTestWithName:name suffix:suffix + 1];
        return;
    }

    NSURL *outputFileURL = [NSURL fileURLWithPath:outputFilePath];
    CGImageRef screenshot = [self screenshot];

    CFURLRef cfURL = (__bridge CFURLRef)outputFileURL;
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(cfURL, kUTTypeJPEG, 1, NULL);
    if (!destination) {
        [BPUtils printInfo:WARNING withString:@"Saving screenshot for failed test: %@, creating destination failed %@", name, destination];
        return;
    }

    CGImageDestinationAddImage(destination, screenshot, nil);
    if (!CGImageDestinationFinalize(destination)) {
        [BPUtils printInfo:WARNING withString:@"Saving screenshot for failed test: %@ failed", name];
        CFRelease(destination);
        return;
    }

    CFRelease(destination);
    [BPUtils printInfo:INFO withString:@"Saved screenshot for failed test: %@", name];
}

- (void)startService {
    [BPUtils printInfo:INFO withString:@"Starting SimulatorScreenshotService for device: %@", self.device.UDID.UUIDString];

    NSString *queueName = [NSString stringWithFormat:@"com.linkedin.bluepill.SimulatorScreenshotService-%@", self.device.UDID.UUIDString];
    self.frameBufferQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);

    [self.frameBufferService registerClient:self onQueue:self.frameBufferQueue];
    [self.frameBufferService resume];
}

- (void)stopService {
    [BPUtils printInfo:INFO withString:@"Stopping SimulatorScreenshotService for device: %@", self.device.UDID.UUIDString];

    [self.frameBufferService unregisterClient:self];
    [self releaseOldIOSurface];
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
    SimDeviceFramebufferService *service = [SimDeviceFramebufferService
                                            mainScreenFramebufferServiceForDevice: device
                                            error: &error];
    if (!service) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"Failed to create FrameBufferService for device: %@, error: %@", self.device.UDID.UUIDString, [error localizedDescription]]];
    }
    return service;
}

- (void)releaseOldIOSurface {
    if (self.ioSurface != NULL) {
        [BPUtils printInfo:DEBUGINFO withString:@"Removing old IO surface from SimulatorScreenshotService"];
        IOSurfaceDecrementUseCount(self.ioSurface);
        CFRelease(self.ioSurface);
        self.ioSurface = nil;
    }
}

#pragma mark SimDisplayIOSurfaceRenderableDelegate

- (void)setIOSurface:(IOSurfaceRef)surface {
    [self releaseOldIOSurface];

    if (surface != NULL) {
        IOSurfaceIncrementUseCount(surface);
        CFRetain(surface);
        [BPUtils printInfo:DEBUGINFO withString:@"Retaining new IO surface for SimulatorScreenshotService"];
        self.ioSurface = surface;
    }
}

- (void)didChangeIOSurface:(nullable id)unknown {

}

#pragma mark SimDisplayDamageRectangleDelegate

- (void)didReceiveDamageRect:(CGRect)rect {
    // Nothing to do here
}

#pragma mark SimDeviceIOPortConsumer

- (NSString *)consumerIdentifier {
    return NSStringFromClass(self.class);
}

- (NSString *)consumerUUID {
    return NSUUID.UUID.UUIDString;
}

@end
