//
//  BPPrefs.h
//  Bluepill-gui
//
//  Created by Ashit Gandhi on 1/9/17.
//  Copyright © 2017 LinkedIn. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BPPrefs : NSObject

+ (instancetype)sharedPrefs;

- (NSString *)defaultApplicationPath;
- (NSString *)defaultTestPath;
- (NSString *)defaultSchemePath;
- (NSString *)defaultOutputPath;

- (NSArray *)applicationPaths;
- (NSArray *)testPaths;
- (NSArray *)schemePaths;
- (NSArray *)outputPaths;

- (void)addApplicationPath:(NSString *)path;
- (void)addTestPath:(NSString *)path;
- (void)addSchemePath:(NSString *)path;
- (void)addOutputPath:(NSString *)path;

@end
