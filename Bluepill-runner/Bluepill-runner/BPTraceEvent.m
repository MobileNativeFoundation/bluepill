//
//  BPTraceEvent.m
//  bluepill
//
//  Created by Eric Snyder on 12/17/18.
//  Copyright © 2018 LinkedIn. All rights reserved.
//

#import "BPTraceEvent.h"

@implementation TraceEvent
- (instancetype)init {
    self = [self initWithData:nil];
    return self;
}

- (instancetype)initWithData:(NSDictionary *)data {
    self = [super init];
    if (self) {
        _displayTimeUnit = @"ms";
        _systemTraceEvents = @"SystemTraceData";
        _otherData = data;
        _stackFrames = [[NSDictionary alloc] init];
        _samples = [NSMutableArray array];
        _traceEvents = [NSMutableArray array];
    }
    return self;
}

- (void)appendCompleteTraceEvent:(NSString *)name
                                :(NSString *)category
                                :(NSInteger)timestamp
                                :(float)duration
                                :(NSInteger)process_id
                                :(NSInteger)thread_id
                                :(NSDictionary *)args {
    NSDictionary *newTraceEvent = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   name, @"name",
                                   category, @"cat",
                                   @"X", @"ph", // Complete event type (with both a timestamp and duration)
                                   [NSString stringWithFormat: @"%ld", (long)timestamp], @"ts",
                                   [[NSNumber numberWithFloat:duration] stringValue], @"dur",
                                   [NSString stringWithFormat: @"%ld", (long)process_id], @"pid",
                                   [NSString stringWithFormat: @"%ld", (long)thread_id], @"tid",
                                   args, @"args",
                                   nil];

    [_traceEvents addObject:newTraceEvent];
}
- (NSDictionary *)toDict {
    return [[NSDictionary alloc] initWithObjectsAndKeys:
            _displayTimeUnit, @"displayTimeUnit",
            _systemTraceEvents, @"systemTraceEvents",
            _otherData, @"otherData",
            _stackFrames, @"stackFrames",
            _samples, @"samples",
            _traceEvents, @"traceEvents",
            nil];
}
@end
