//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPReporters.h"
#import "BPTreeObjects.h"

void Output(NSMutableString *appendTo, NSString *fmt, ...);

@implementation StandardReporter

- (nullable NSString *)generate:(nonnull BPLogEntry *)root {
    return [root description];
}

@end

@implementation JSONReporter

- (nullable NSString *)generate:(nonnull BPLogEntry *)root {
    if ([root isKindOfClass:[BPTestSuiteLogEntry class]]) {
        NSMutableString *output = [NSMutableString string];
        [self generateJSONAt:root intoString:output];
        // Remove the last comma
        if ([output length] > 1) { // Remove the ",\n" at the end
            [output replaceCharactersInRange:NSMakeRange([output length]-2, 2) withString:@""];
        }
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'GMT'ZZZZZ";
        dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // Always get nil for stringFromDate: without this
        return [NSString stringWithFormat:@"{\"date\" : \"%@\",\n\"results\" : [%@]}", [dateFormatter stringFromDate:[NSDate date]], output];
    }
    return nil;
}

- (void)generateJSONAt:(nonnull BPLogEntry *)logEntry intoString:(nonnull NSMutableString *)output {
    if ([logEntry isKindOfClass:[BPTestSuiteLogEntry class]]) {
        BPTestSuiteLogEntry *suiteLogEntry = (BPTestSuiteLogEntry *)logEntry;
        for (BPLogEntry *suiteChild in suiteLogEntry.children) {
            [self generateJSONAt:suiteChild intoString:output];
        }
    } else if([logEntry isKindOfClass:[BPTestCaseLogEntry class]]) {
        BPTestCaseLogEntry *caseLogEntry = (BPTestCaseLogEntry *)logEntry;
        if (caseLogEntry.passed) {
            Output(output, @"{\"testCaseFullName\" : \"%@/%@\", \"time\" : %f},",
                   caseLogEntry.testCaseClass, caseLogEntry.testCaseName, caseLogEntry.totalTime);
        }
    }
}

@end

@interface JUnitReporter ()

@property (nonatomic, strong, nullable) BPTestSuiteLogEntry *root;

@end

@implementation JUnitReporter

+ (BOOL)suppressStackTracesInOutput {
    // Change this to true if you do not want stack traces to appear in the junit output
    return NO;
}

- (nullable NSString *)generate:(nonnull BPLogEntry *)root {
    if ([root isKindOfClass:[BPTestSuiteLogEntry class]]) {
        self.root = (BPTestSuiteLogEntry *)root;
        NSMutableString *output = [NSMutableString string];
        Output(output, @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        Output(output, @"<testsuites name=\"%@\" tests=\"%lu\" failures=\"%lu\" errors=\"%lu\" time=\"%f\">",
               self.root.testSuiteName, self.root.numberOfTests, self.root.numberOfFailures, self.root.numberOfErrors, self.root.totalTime);
        [self generateJunitAt:self.root withIndentLevel:0 intoString:output];
        Output(output, @"</testsuites>");
        return output;
    }
    return nil;
}

- (void)generateJunitAt:(nonnull BPLogEntry *)logEntry withIndentLevel:(NSInteger)indent intoString:(nonnull NSMutableString *)output {
    if ([logEntry isKindOfClass:[BPTestSuiteLogEntry class]]) {
        BPTestSuiteLogEntry *suiteLogEntry = (BPTestSuiteLogEntry *)logEntry;
        if (suiteLogEntry != self.root) {
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'GMT'ZZZZZ";
            dateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]; // Always get nil for stringFromDate: without this
            Output(output, @"%@<testsuite tests=\"%lu\" failures=\"%lu\" errors=\"%lu\" time=\"%f\" timestamp=\"%@\" name=\"%@\">",
                   [@"" stringByPaddingToLength:(indent*2) withString:@" " startingAtIndex:0],
                   suiteLogEntry.numberOfTests, suiteLogEntry.numberOfFailures, suiteLogEntry.numberOfErrors,
                   suiteLogEntry.totalTime,
                   [dateFormatter stringFromDate:suiteLogEntry.startTime],
                   [JUnitReporter xmlSimpleEscape:suiteLogEntry.testSuiteName]);
        }
        for (BPLogEntry *suiteChild in suiteLogEntry.children) {
            [self generateJunitAt:suiteChild withIndentLevel:indent+1 intoString:output];
        }
        if (suiteLogEntry != self.root) {
            Output(output, @"%@</testsuite>", [@"" stringByPaddingToLength:(indent*2) withString:@" " startingAtIndex:0]);
        }
    } else if ([logEntry isKindOfClass:[BPTestCaseLogEntry class]]) {
        BPTestCaseLogEntry *caseLogEntry = (BPTestCaseLogEntry *)logEntry;

        Output(output, @"%@<testcase classname=\"%@\" name=\"%@\" time=\"%f\">",
               [@"" stringByPaddingToLength:(indent*2) withString:@" " startingAtIndex:0],
               [JUnitReporter xmlSimpleEscape:caseLogEntry.testCaseClass],
               [JUnitReporter xmlSimpleEscape:caseLogEntry.testCaseName],
               caseLogEntry.totalTime);

        if (!caseLogEntry.passed) {
            NSString *entity = @"error";
            NSString *attribute = @"Error";
            if (caseLogEntry.failure) {
                entity = @"failure";
                attribute = @"Failure";
            }
            Output(output, @"%@<%@ type=\"%@\" message=\"%@\">\n%@:%lu\n%@</%@>",
                   [@"" stringByPaddingToLength:((indent+1)*2) withString:@" " startingAtIndex:0],
                   entity, attribute,
                   [JUnitReporter xmlSimpleEscape:caseLogEntry.errorMessage] ?: [@"UNKNOWN ERROR - PARSING FAILED: " stringByAppendingString:caseLogEntry.line],
                   [JUnitReporter xmlSimpleEscape:caseLogEntry.filename ?: @"Unknown File"],
                   caseLogEntry.lineNumber,
                   [@"" stringByPaddingToLength:((indent+1)*2) withString:@" " startingAtIndex:0],
                   entity);
        }

        if (caseLogEntry.log) {
            if (![JUnitReporter suppressStackTracesInOutput] || ![caseLogEntry.log containsString:@"BP_"]) {
                Output(output, @"%@<system-out>\n%@%@</system-out>",
                       [@"" stringByPaddingToLength:((indent+1)*2) withString:@" " startingAtIndex:0],
                       [JUnitReporter xmlSimpleEscape:caseLogEntry.log],
                       [@"" stringByPaddingToLength:((indent+1)*2) withString:@" " startingAtIndex:0]);
            }
        }

        Output(output, @"%@</testcase>", [@"" stringByPaddingToLength:(indent*2) withString:@" " startingAtIndex:0]);
    }
}

+ (NSString *)xmlSimpleEscape:(NSString *)originalString {
    if(!originalString) {
        return nil;
    }
    NSMutableString *string = [[NSMutableString alloc] initWithString:originalString];
    [string replaceOccurrencesOfString:@"&"  withString:@"&amp;"  options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"'"  withString:@"&#x27;" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@">"  withString:@"&gt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];
    [string replaceOccurrencesOfString:@"<"  withString:@"&lt;"   options:NSLiteralSearch range:NSMakeRange(0, [string length])];

    return [NSString stringWithString:string];
}

@end

void Output(NSMutableString *appendTo, NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *str = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [appendTo appendString:str];
    [appendTo appendString:@"\n"];
}
