//
//  BPPrefs.m
//  Bluepill-gui
//
//  Created by Ashit Gandhi on 1/9/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import "BPPrefs.h"

#define kApplicationPaths   @"ApplicationPaths"
#define kTestPaths          @"TestPaths"
#define kSchemePaths        @"SchemePaths"
#define kOutputPaths        @"OutputPaths"

@interface BPPrefs()

@property (nonatomic, strong) NSUserDefaults *prefs;

@end

@implementation BPPrefs

+ (instancetype)sharedPrefs {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.prefs = [NSUserDefaults standardUserDefaults];
    }
    return self;
}

- (NSString *)defaultApplicationPath {
    NSArray *appPaths = [self.prefs arrayForKey:kApplicationPaths];
    return [appPaths objectAtIndex:0] ?: @"";
}

- (NSString *)defaultTestPath {
    NSArray *testPaths = [self.prefs arrayForKey:kTestPaths];
    return [testPaths objectAtIndex:0] ?: @"";
}

- (NSString *)defaultSchemePath {
    NSArray *schemePaths = [self.prefs arrayForKey:kSchemePaths];
    return [schemePaths objectAtIndex:0] ?: @"";
}

- (NSString *)defaultOutputPath {
    NSArray *outputPaths = [self.prefs arrayForKey:kOutputPaths];
    return [outputPaths objectAtIndex:0] ?: @"";
}

- (NSArray *)applicationPaths {
    return [self.prefs arrayForKey:kApplicationPaths];
}

- (NSArray *)testPaths {
    return [self.prefs arrayForKey:kTestPaths];
}

- (NSArray *)schemePaths {
    return [self.prefs arrayForKey:kSchemePaths];
}

- (NSArray *)outputPaths {
    return [self.prefs arrayForKey:kOutputPaths];
}

- (void)addApplicationPath:(NSString *)path {
    if (!path || ![path length]) {
        return;
    }
    NSMutableArray *appPaths = [[self.prefs arrayForKey:kApplicationPaths] mutableCopy];
    if (!appPaths) {
        appPaths = [[NSMutableArray alloc] init];
    }
    if (![appPaths containsObject:path]) {
        [appPaths addObject:path];
        [self.prefs setObject:appPaths forKey:kApplicationPaths];
        [self.prefs synchronize];
    }
}

- (void)addTestPath:(NSString *)path {
    if (!path || ![path length]) {
        return;
    }
    NSMutableArray *testPaths = [[self.prefs arrayForKey:kTestPaths] mutableCopy];
    if (!testPaths) {
        testPaths = [[NSMutableArray alloc] init];
    }
    if (![testPaths containsObject:path]) {
        [testPaths addObject:path];
        [self.prefs setObject:testPaths forKey:kTestPaths];
        [self.prefs synchronize];
    }
}

- (void)addSchemePath:(NSString *)path {
    if (!path || ![path length]) {
        return;
    }
    NSMutableArray *schemePaths = [[self.prefs arrayForKey:kSchemePaths] mutableCopy];
    if (!schemePaths) {
        schemePaths = [[NSMutableArray alloc] init];
    }
    if (![schemePaths containsObject:path]) {
        [schemePaths addObject:path];
        [self.prefs setObject:schemePaths forKey:kSchemePaths];
        [self.prefs synchronize];
    }
}

- (void)addOutputPath:(NSString *)path {
    if (!path || ![path length]) {
        return;
    }
    NSMutableArray *outputPaths = [[self.prefs arrayForKey:kOutputPaths] mutableCopy];
    if (!outputPaths) {
        outputPaths = [[NSMutableArray alloc] init];
    }
    if (![outputPaths containsObject:path]) {
        [outputPaths addObject:path];
        [self.prefs setObject:outputPaths forKey:kOutputPaths];
        [self.prefs synchronize];
    }
}

@end
