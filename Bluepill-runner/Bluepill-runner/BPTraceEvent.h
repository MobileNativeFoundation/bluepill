//
//  BPTraceEvent.h
//  Bluepill
//
//  Created by Eric Snyder on 12/17/18.
//  Copyright © 2018 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 Trace Event Format Definition: https://docs.google.com/document/d/1CvAClvFfyA5R-PhYUmn5OOQtYMH4h6I0nSsKchNAySU
 */

@interface BPTraceEvent : NSObject
@property (strong, nonatomic) NSMutableArray *traceEvents;
@property (strong, nonatomic) NSString *displayTimeUnit;
@property (strong, nonatomic) NSString *systemTraceEvents;
@property (strong, nonatomic) NSDictionary *otherData;
@property (strong, nonatomic) NSDictionary *stackFrames;
@property (strong, nonatomic) NSArray *samples;

- (instancetype)initWithData:(NSDictionary *)data;

/*!
 * @discussion Appends a full TraceEvent to the list of events
 * @param name Name of the event
 * @param category Type of the event, for complete events this will be 'X', indicating the event will contain a duration and implicitly it is an event that has both a beginning and an end (See Trace Event Definition document for more)
 * @param timestamp Unix timestamp indicating when the event started
 * @param duration Length of a complete event
 * @param processId ID of the process the event occured on
 * @param threadId ID of the thread the event ocurred on
 * @param args Additional key value pairs to attach to the event
 */
- (void)appendCompleteTraceEvent:(NSString *)name
                        category:(NSString *)category
                       timestamp:(NSInteger)timestamp
                        duration:(NSInteger)duration
                       processId:(NSInteger)processId
                        threadID:(NSInteger)threadId
                            args:(NSDictionary *)args;

- (NSDictionary *)toDict;
@end
