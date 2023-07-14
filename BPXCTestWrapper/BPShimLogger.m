////
////  BPShimLogger.m
////  Experiment
////
////  Created by Lucas Throckmorton on 5/30/23.
////
//
//#import "BPShimLogger.h"
//
//#import <Foundation/Foundation.h>
//
//@interface BPShimLogger ()
//
//@property (nonatomic, strong, nonnull) NSString *outputPath;
//@property (nonatomic, strong, nonnull) NSFileHandle *fileHandle;
//
//@end
//
//@implementation BPShimLogger
//
//#pragma mark - init
//
//- (nonnull instancetype)initWithOutputPath:(NSString *)outputPath {
//    if (self = [super init]) {
//        _outputPath = outputPath;
//        [self createLogFileAtPath:outputPath];
//    }
//    return self;
//}
//
//#pragma mark - Properties
//
//+ (NSString *)outputPathEnvironmentKey {
//    return @"BPSHIM_OUTPUT_PATH";
//}
//
//+ (BPShimLogger *)defaultLogger {
//    // Grab and then unset env variable to avoid impacting future processes
//    NSString *outputPath = NSProcessInfo.processInfo.environment[BPShimLogger.outputPathEnvironmentKey];
//    unsetenv(BPShimLogger.outputPathEnvironmentKey.UTF8String);
//
//    static BPShimLogger * instance;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        instance = [[self alloc] initWithOutputPath:outputPath];
//    });
//    return instance;
//}
//
//#pragma mark - public
//
//- (void)log:(NSString *)text {
//    // First to console
//    NSLog(@"__EXPERIMENT: %@", text);
//    // Then to file
//    NSString *line = [NSString stringWithFormat:@"%@\n", text];
//    [self.fileHandle seekToEndOfFile];
//    [self.fileHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
//}
//
//- (void)tearDown {
//    // TODO: output EOF stuff
//    // TODO: close file handle if needed.
//}
//
//#pragma mark - private
//
//- (void)createLogFileAtPath:(NSString *)outputPath {
//    [[NSFileManager defaultManager] createFileAtPath:outputPath contents:nil attributes:nil];
//    self.fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:outputPath];
//}
//
//@end
