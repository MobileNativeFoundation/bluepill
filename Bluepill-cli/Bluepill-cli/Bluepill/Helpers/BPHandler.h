//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import <Foundation/Foundation.h>

@class BPWaitTimer;

@interface BPHandler : NSObject  {
    dispatch_once_t onceToken;
}

typedef void (^BasicHandlerBlock)(void);
typedef void (^BasicErrorBlock)(NSError *error);

@property (nonatomic, strong) BPWaitTimer *timer;

@property (nonatomic, copy) BasicHandlerBlock beginWith;
@property (nonatomic, copy) BasicHandlerBlock onSuccess;
@property (nonatomic, copy) BasicErrorBlock onError;
@property (nonatomic, copy) BasicHandlerBlock endWith;
@property (nonatomic, copy) BasicHandlerBlock onTimeout;

// Properties that are stored from the callback
@property (nonatomic, strong) NSError *error;

+ (instancetype)handlerWithTimer:(BPWaitTimer *)timer;
- (BasicErrorBlock)defaultHandlerBlock;

@end

#import "BPCreateSimulatorHandler.h"
#import "BPDeleteSimulatorHandler.h"
#import "BPApplicationLaunchHandler.h"
