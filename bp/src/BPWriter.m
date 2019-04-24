//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPWriter.h"

@interface BPWriter ()

@property (nonatomic, assign) BPWriterDestination destination;
@property (nonatomic, strong) NSString *filePath;

@end

@implementation BPWriter

- (nonnull instancetype)initWithDestination:(BPWriterDestination)destination {
    return [self initWithDestination:destination andPath:nil];
}

- (nonnull instancetype)initWithDestination:(BPWriterDestination)destination andPath:(nullable NSString *)filePath {
    self = [super init];
    if (self) {
        if (destination == BPWriterDestinationFile && (!filePath || [filePath length] == 0)) {
            [self writeError:@"%@", @"CANNOT LOG TO FILE WHEN NO FILE PATH IS SPECIFIED! DUMPING TO STDOUT."];
            destination = BPWriterDestinationStdout;
        }
        self.destination = destination;
        self.filePath = filePath;
    }
    return self;
}

- (void)removeFile {
    switch (self.destination) {
        case BPWriterDestinationFile: {
            NSError *error = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:self.filePath]) {
                [[NSFileManager defaultManager] removeItemAtPath:self.filePath error:&error];
                if(error) {
                    [self writeError:@"Could not remove '%@': %@", self.filePath, error];
                }
            }
            break;
        }
        default:
            break;
    }
}

- (void)writeLine:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    switch (self.destination) {
        case BPWriterDestinationStdout:
            fprintf(stdout, "%s\n", [str UTF8String]);
            break;
        case BPWriterDestinationStdErr:
            fprintf(stderr, "%s\n", [str UTF8String]);
            break;
        case BPWriterDestinationFile: {
            FILE *filePointer = fopen([self.filePath UTF8String], "a+");
            if (filePointer) {
                fprintf(filePointer, "%s\n", [str UTF8String]);
                fclose(filePointer);
            } else {
                fprintf(stderr, "Could not open file %s for append!", [self.filePath UTF8String]);
            }
            break;
        }
    }
}

- (void)writeError:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    fprintf(stderr, "%s\n", [str UTF8String]);
}

@end
