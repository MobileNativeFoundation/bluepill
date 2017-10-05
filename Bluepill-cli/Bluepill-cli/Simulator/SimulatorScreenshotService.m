//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "SimulatorScreenshotService.h"
#import "SimDeviceFramebufferService.h"
#import "BPUtils.h"
#import <CoreImage/CoreImage.h>

@interface SimulatorScreenshotService()

@property (nonatomic, strong) BPConfiguration *config;
@property (nonatomic, strong) SimDevice *device;
@property (nonatomic, strong) SimDeviceFramebufferService *frameBufferService;
@property (nonatomic, strong) dispatch_queue_t frameBufferQueue;
@property (nonatomic) IOSurfaceRef ioSurface;

@end

@implementation SimulatorScreenshotService

- (instancetype)initWithConfiguration:(BPConfiguration *)config forDevice:(SimDevice *)device {
    self = [super init];
    if (self) {
        _config = config;
        _device = device;

        if ([self meetsPreconditionsForConnectingToDevice:device]) {
            _frameBufferService = [self createMainScreenServiceForDevice:device];
            [self startService];
        }
    }

    return self;
}

- (void)dealloc {
    [self stopService];
}

- (CGImageRef)screenshot {
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *ciImage = [CIImage imageWithIOSurface:_ioSurface];

    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    if (!cgImage) {
        [BPUtils printInfo:ERROR withString:@"Rendering simulator screenshot failed, returning null"];
        return NULL;
    }

    return cgImage;
}

- (void)saveScreenshotForFailedTestWithName:(NSString *)name {
    [self saveScreenshotForFailedTestWithName:name suffix:1];
}

- (void)saveScreenshotForFailedTestWithName:(NSString *)name suffix:(int)suffix {
    NSString *outputFilePath = [NSString stringWithFormat:@"%@/%@_attempt_%d.jpeg", _config.screenshotsDirectory, name, suffix];

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
        [BPUtils printInfo:WARNING withString:@"Saving screenshot for failed test:%@, creating destination failed %@", name, destination];
        return;
    }

    CGImageDestinationAddImage(destination, screenshot, nil);
    if (!CGImageDestinationFinalize(destination)) {
        [BPUtils printInfo:WARNING withString:@"Saving screenshot for failed test:%@ failed", name];
        CFRelease(destination);
        return;
    }

    CFRelease(destination);
    [BPUtils printInfo:INFO withString:@"Saved screenshot for failed test:%@", name];
}

- (void)startService {
    [BPUtils printInfo:INFO withString:@"Starting SimulatorScreenshotService for device:%@", _device.UDID.UUIDString];

    NSString *queueName = [NSString stringWithFormat:@"com.linkedin.bluepill.SimulatorScreenshotService-%@", _device.UDID.UUIDString];
    _frameBufferQueue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);

    [_frameBufferService registerClient:self onQueue:_frameBufferQueue];
    [_frameBufferService resume];
}

- (void)stopService {
    [BPUtils printInfo:INFO withString:@"Stopping SimulatorScreenshotService for device:%@", _device.UDID.UUIDString];

    [_frameBufferService unregisterClient:self];
    [self releaseOldIOSurface];
}

- (void)releaseOldIOSurface {
    if (_ioSurface != NULL) {
        [BPUtils printInfo:DEBUGINFO withString:@"Removing old IO surface from SimulatorScreenshotService"];
        IOSurfaceDecrementUseCount(_ioSurface);
        CFRelease(_ioSurface);
        _ioSurface = nil;
    }
 }

#pragma mark - Private Methods

- (BOOL)meetsPreconditionsForConnectingToDevice:(SimDevice *)device {
    if ([device.stateString isEqualToString:@"Booted"] || [device.stateString isEqualToString:@"Shutdown"]) {
        return YES;
    }

    [BPUtils printInfo:ERROR withString:@"ScreenshotService can't be created for device:%@. Device has wrong state:%@", _device.UDID.UUIDString, device.stateString];
    return NO;
}

- (SimDeviceFramebufferService *)createMainScreenServiceForDevice:(SimDevice *)device {
    NSError *error = nil;
    SimDeviceFramebufferService *service = [SimDeviceFramebufferService
                                            mainScreenFramebufferServiceForDevice:device
                                            error:&error];

    if (!service) {
        [BPUtils printInfo:ERROR withString:[NSString stringWithFormat:@"Failed to create SimDeviceFramebufferService for device:%@, error:%@", _device.UDID.UUIDString, [error localizedDescription]]];
    }
    return service;
}

#pragma mark - protocol methods called from SimDeviceFramebufferService

- (void)setIOSurface:(IOSurfaceRef)surface {
    [self releaseOldIOSurface];

    if (surface != NULL) {
        IOSurfaceIncrementUseCount(surface);
        CFRetain(surface);
        [BPUtils printInfo:DEBUGINFO withString:@"Retaining new IO surface for SimulatorScreenshotService"];
        _ioSurface = surface;
    }
 }

- (void)framebufferService:(SimDeviceFramebufferService *)service didRotateToAngle:(double)angle {
    // Nothing to do here?
}

@end
