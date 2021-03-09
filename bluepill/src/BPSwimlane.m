//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "bp/src/BPUtils.h"
#import "BPSwimlane.h"

@interface BPSwimlane()

@property (nonatomic, assign) NSUInteger laneID;
@property (nonatomic, strong) NSTask *task;

@end

@implementation BPSwimlane

+ (instancetype)BPSwimlaneWithLaneID:(NSUInteger)laneID {
    BPSwimlane *bpTask = [[BPSwimlane alloc] init];
    bpTask.laneID = laneID;
    return bpTask;
}

- (void)launchTaskWithBundle:(BPXCTestFile *)bundle
                   andConfig:(BPConfiguration *)config
               andLaunchPath:(NSString *)launchPath
                   andNumber:(NSUInteger)number
                   andDevice:(NSString *)deviceID
          andTemplateSimUDID:(NSString *)templateSimUDID
          andCompletionBlock:(void (^)(NSTask *))block {
    self.isBusy = YES;
    self.taskNumber = number;

    BPConfiguration *cfg = [config mutableCopy];
    assert(cfg);
    cfg.appBundlePath = bundle.UITargetAppPath ?: bundle.testHostPath;
    cfg.testBundlePath = bundle.testBundlePath;
    cfg.testRunnerAppPath = bundle.UITargetAppPath ? bundle.testHostPath : nil;
    cfg.testCasesToSkip = bundle.skipTestIdentifiers;
    if (cfg.commandLineArguments) {
        [cfg.commandLineArguments arrayByAddingObjectsFromArray:bundle.commandLineArguments];
    } else {
        cfg.commandLineArguments = bundle.commandLineArguments;
    }
    if (cfg.environmentVariables) {
        NSMutableDictionary *newEnv = [[NSMutableDictionary alloc] initWithDictionary:cfg.environmentVariables];
        for (NSString *key in bundle.environmentVariables) {
            newEnv[key] = bundle.environmentVariables[key];
        }
        cfg.environmentVariables = (NSDictionary<NSString *, NSString *>*) newEnv;
    } else {
        cfg.environmentVariables = bundle.environmentVariables;
    }
    cfg.dependencies = bundle.dependencies;
    if (config.cloneSimulator) {
        cfg.templateSimUDID = templateSimUDID;
    }
    NSError *err;
    NSString *tmpFileName = [NSString stringWithFormat:@"%@/bluepill-%u-config",
                             NSTemporaryDirectory(),
                             getpid()];

    cfg.configOutputFile = [BPUtils mkstemp:tmpFileName withError:&err];
    if (!cfg.configOutputFile) {
        fprintf(stderr, "ERROR: %s\n", [[err localizedDescription] UTF8String]);
        return;
    }
    cfg.outputDirectory = [config.outputDirectory
                           stringByAppendingPathComponent:
                           [NSString stringWithFormat:@"BP-%lu", (unsigned long)number]];
    cfg.testTimeEstimatesJsonFile = config.testTimeEstimatesJsonFile;
    [cfg printConfig];

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:launchPath];
    [task setArguments:@[@"-c", cfg.configOutputFile]];
    NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
    [env addEntriesFromDictionary:[[NSProcessInfo processInfo] environment]];
    [env setObject:[NSString stringWithFormat:@"%lu", number] forKey:@"_BP_NUM"];
    [env setObject:[NSString stringWithFormat:@"%lu", self.laneID] forKey:@"_BP_INDEX"];
    [task setEnvironment:env];
    [task setTerminationHandler:^(NSTask *task) {
        self.isBusy = NO;
        self.task = nil;

        [[NSFileManager defaultManager] removeItemAtPath:cfg.configOutputFile
                                                   error:nil];
        [BPUtils printInfo:INFO withString:@"BP-%lu (PID %u) has finished with exit code %d.",
                                            number, [task processIdentifier], [task terminationStatus]];
        block(task);
    }];

    if (!task) {
        self.isBusy = NO;
        [BPUtils printInfo:ERROR withString:@"task is nil!"];
        exit(1);
    }

    [task launch];
    self.task = task;
    [BPUtils printInfo:INFO withString:@"Started BP-%lu (PID %d).", number, [task processIdentifier]];
}

- (void)interrupt {
    [self.task interrupt];
    self.isBusy = NO;
}

@end
