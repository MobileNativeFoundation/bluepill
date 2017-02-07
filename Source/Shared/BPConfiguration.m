//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "BPConfiguration.h"
#import "BPUtils.h"
#import <getopt.h>
#import <objc/runtime.h>
#import "BPConstants.h"

#define BP_VALUE 1 // Single value
#define BP_LIST  2 // List value
#define BP_PATH  4 // Single value, CWD will be prepended
#define BP_BOOL  8 // Boolean variable

// This data structure is shared between `bp` and `bluepill` to keep the
// arguments consistent and also make it easier to share config files
// between the two.
struct BPOptions {
    int         val;          // short option (e.g. -f)
    const char  *name;        // long name of the option (e.g. --foobar)
    int         has_arg;      // One of: no_argument, required_argument, optional_argument
    const char  *default_val; // Default value (if option not provided)
    int         kind;         // List vs value.
    const char  *property;    // Which class property to set (via KVO)
    const char  *help;        // Help string, what the option does.
} BPOptions[] = {

    // Required argument
    {'a', "app",      required_argument, NULL, BP_VALUE | BP_PATH, "appBundlePath",
        "The path to the host application to execute (your .app)"},
    {'o', "output-dir", required_argument, NULL, BP_VALUE | BP_PATH, "outputDirectory",
        "Directory where to put output log files (bluepill only)."},
    {'s', "scheme-path", required_argument, NULL, BP_VALUE | BP_PATH, "schemePath",
        "The scheme to run tests."},

    // Optional argument
    {'d', "device",   required_argument, BP_DEFAULT_DEVICE_TYPE, BP_VALUE, "deviceType",
        "On which device to run the app."},
    {'c', "config",   required_argument, NULL, BP_VALUE, "configFile",
        "Read options from the specified configuration file instead of the command line"},
    {'C', "repeat-count", required_argument, "1", BP_VALUE, "repeatTestsCount",
        "Number of times we'll run the entire test suite (used for stability testing)."},
    {'N', "no-split", required_argument, NULL, BP_LIST, "noSplit",
        "A list of NO split test bundles"},
    {'P', "print-config", required_argument, "stdout", BP_VALUE, "configOutputFile",
        "Print a configuration file suitable for passing back using the `-c` option."},
    {'R', "error-retries", required_argument, "4", BP_VALUE, "errorRetriesCount",
        "Number of times we'll recover from crashes to continue running the current test suite."},
    {'S', "stuck-timeout", required_argument, "300", BP_VALUE, "stuckTimeout",
        "Timeout in seconds for a test that seems stuck (no output)."},
    {'T', "test-timeout", required_argument, "300", BP_VALUE, "testCaseTimeout",
        "Timeout in seconds for a test that is producing output."},
    {'f', "failure-tolerance",   required_argument, NO, BP_VALUE, "failureTolerance",
        "The number of retries on any failures (app crash/test failure)."},
    {'i', "include", required_argument, NULL, BP_LIST, "testCasesToRun",
        "Include a testcase in the set of tests to run (unless specified in `exclude`)."},
    {'n', "num-sims", required_argument, "4", BP_VALUE, "numSims",
        "Number of simulators to run in parallel. (bluepill only)"},
    {'r', "runtime",  required_argument, BP_DEFAULT_RUNTIME, BP_VALUE, "runtime",
        "What runtime to use."},
    {'t', "test",     required_argument, NULL, BP_VALUE | BP_PATH, "testBundlePath",
        "The path to the test bundle to execute (your .xctest)."},
    {'x', "exclude", required_argument, NULL, BP_LIST, "testCasesToSkip",
        "Exclude a testcase in the set of tests to run (takes priority over `include`)."},
    {'X', "xcode-path", required_argument, NULL, BP_VALUE | BP_PATH, "xcodePath",
        "Path to xcode."},

    // options with no argument
    {'H', "headless", no_argument, "Off", BP_VALUE | BP_BOOL , "headlessMode",
        "Run in headless mode (no GUI)."},
    {'J', "json-output", no_argument, "Off", BP_VALUE | BP_BOOL, "jsonOutput",
        "Print test timing information in JSON format."},
    {'h', "help",     no_argument, NULL, BP_VALUE, NULL,
        "This help."},
    {'p', "plain-output", no_argument, "Off", BP_VALUE | BP_BOOL, "plainOutput",
        "Print results in plain text."},
    {'q', "quiet", no_argument, "Off", BP_VALUE | BP_BOOL, "quiet",
        "Turn off all output except fatal errors."},
    {'j', "junit-output", no_argument, "Off", BP_VALUE | BP_BOOL, "junitOutput",
        "Print results in JUnit format."},
    {'F', "only-retry-failed", no_argument, "Off", BP_VALUE | BP_BOOL, "onlyRetryFailed",
        "If `failure-tolerance` is > 0, only retry tests that failed."},
    {'l', "list-tests", no_argument, NULL, BP_VALUE, "listTestsOnly",
        "Only list tests in bundle"},

    // options without short-options
    {350, "additional-xctests", required_argument, NULL, BP_LIST | BP_PATH, "additionalTestBundles",
        "Additional XCTest bundles to test."},
    {0, 0, 0, 0}
};


@implementation BPConfiguration

#pragma mark instance methods

- (instancetype)init {
    return [self initWithConfigFile:nil error:nil];
}

- (instancetype)initWithConfigFile:(NSString *)file error:(NSError **)err {
    self = [super init];
    self.cmdLineArgs = [[NSMutableArray alloc] init];
    // set factory defaults
    for (int i = 0; BPOptions[i].name; i++) {
        if (BPOptions[i].default_val) {
            [self handleOpt:BPOptions[i].val withArg:(char *)BPOptions[i].default_val];
        }
    }
    if (!file || [self loadConfigFile:file withError:err]) {
        return self;
    }
    return nil;
}

- (void)saveOpt:(NSNumber *)opt withArg:(NSString *)arg {
    [self.cmdLineArgs addObject:@[opt, arg]];
}

- (void)handleOpt:(int)opt withArg:(char *)arg {
    struct BPOptions *bpo = NULL;

    for (int i = 0; BPOptions[i].name; i++) {
        if (BPOptions[i].val == opt) {
            bpo = &BPOptions[i];
            break;
        }
    }
    if (bpo == NULL) [self usage:-1]; // exits
    assert(bpo && bpo->name);
    if (!strcmp(bpo->name, "help")) [self usage:0];
    [self setProperty:bpo withArg:arg];
}

- (void)setProperty:(struct BPOptions *)bpo withArg:(char *)arg {
    assert(bpo);
    NSString *value = [NSString stringWithUTF8String:arg];
    assert(value);

    // If the value is of type BP_PATH, we append the CWD if the path is relative path
    if (bpo->kind & BP_PATH) {
        NSString *currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
        if (![value isAbsolutePath]) {
            value = [currentPath stringByAppendingPathComponent:value];
        }
    }
    if (bpo->kind & BP_VALUE) {
        NSString *propName = [NSString stringWithUTF8String:bpo->property];
        if (bpo->has_arg == no_argument) {
            // this is a flag
            if (bpo->kind & BP_BOOL) {
                //To treat empty string as TRUE seems hacky, but it is OK for now
                //because we assuem this only happens when we process CLI options,
                //in which case the empty string means turn ON the boolean flag from CLI
                BOOL v = [value length] ==0 ? TRUE :  [value boolValue];
                [self setValue:[NSNumber numberWithBool:v]
                        forKey:propName];
            } else {
                // The flag is of numeric type so increment it
                id value = [self valueForKey:propName];
                NSNumber *v = value;
                [self setValue:[NSNumber numberWithInt:[v intValue] + 1]
                        forKey:propName];
            }
        } else {
            [self setValue:value
                    forKey:propName];
        }
    } else if (bpo->kind & BP_LIST) {
        NSString *property = [NSString stringWithUTF8String:bpo->property];
        NSMutableArray *a = [self valueForKey:property];
        if (a) {
            [a addObject:value];
        } else {
            NSMutableArray *a = [[NSMutableArray alloc] initWithArray:@[value]];
            [self setValue:a forKey:property];
        }
    }
}

- (void)printConfig {
    NSError *err;
    NSString *jsonString = [self configString];
    if (!jsonString) {
        return;
    }
    if (!self.configOutputFile || [BPUtils isStdOut:self.configOutputFile]) {
        printf("%s\n", [jsonString UTF8String]);
    } else if (![jsonString writeToFile:self.configOutputFile
                             atomically:NO
                               encoding:NSUTF8StringEncoding
                                  error:&err]) {
        fprintf(stderr, "Could not write config to file %s\nERROR: %s\n",
                [self.configOutputFile UTF8String], [[err localizedDescription] UTF8String]);
    }
}

- (NSString *)configString {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for(int i = 0; BPOptions[i].name; i++) {
        const char *name = BPOptions[i].property;
        // skip the config file name itself
        if (!name || !strcmp(name, "configOutputFile")) continue;
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:key];
        NSString *cfgName = [NSString stringWithUTF8String:BPOptions[i].name];
        [dict setValue:value forKey:cfgName];
    }
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *err;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&err];
        if (!json) {
            NSLog(@"%@", err);
            return nil;
        }
        NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        return jsonString;
    } else {
        NSLog(@"Error: configuration not serializable.");
    }
    return nil;
}

-(id)copyWithZone:(NSZone *)zone {
    // gross
    return [self mutableCopyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    BPConfiguration *newConfig = [[BPConfiguration alloc] init];
    for(int i = 0; BPOptions[i].name; i++) {
        const char *name = BPOptions[i].property;
        if (!name) continue;
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:key];
        [newConfig setValue:[value copy] forKey:key];
    }
#ifdef BP_USE_PRIVATE_FRAMEWORKS
    newConfig.simRuntime = self.simRuntime;
    newConfig.simDeviceType = self.simDeviceType;
#endif
    newConfig.xcodePath = self.xcodePath;
    newConfig.testing_CrashAppOnLaunch = self.testing_CrashAppOnLaunch;
    newConfig.testing_HangAppOnLaunch = self.testing_HangAppOnLaunch;
    newConfig.testing_NoAppWillRun = self.testing_NoAppWillRun;

    return newConfig;
}

#pragma mark static methods

+ (struct option *)getLongOptions {
    struct option *opt = {0};
    int i;
    for (i = 0; BPOptions[i].name; i++) {}
    opt = malloc(sizeof(struct option) * (i + 1));
    assert(opt);
    for (i = 0; BPOptions[i].name; i++) {
        opt[i].name = BPOptions[i].name;
        opt[i].has_arg = BPOptions[i].has_arg;
        opt[i].flag = NULL;
        opt[i].val = BPOptions[i].val;
    }
    opt[i].name = NULL;
    opt[i].has_arg = 0;
    opt[i].flag = NULL;
    opt[i].val = 0;
    return opt;
}

+ (char *)getShortOptions {
    char *opt;
    int i, j;
    for (i = 0; BPOptions[i].name; i++) {}
    opt = malloc(i * 2 + 1);
    for (i = 0, j = 0; BPOptions[i].name; i++) {
        if (!isascii(BPOptions[i].val)) continue;
        opt[j++] = BPOptions[i].val;
        if (BPOptions[i].has_arg == required_argument) {
            opt[j++] = ':';
        } else if (BPOptions[i].has_arg == optional_argument) {
            opt[j++] = ';';
        }
    }
    opt[j] = 0;
    return opt;
}

- (void)usage:(int)rc {
    char required_arg[] = "<required_arg>";
    char optional_arg[] = "<opt_arg>";
    char no_arg[]       = "";
    char *arg;
    char defstr[1<<8];

    printf("Usage:\n");
    for (int i = 0; BPOptions[i].name; i++) {
        if (BPOptions[i].has_arg == required_argument) {
            arg = required_arg;
        } else if (BPOptions[i].has_arg == optional_argument){
            arg = optional_arg;
        } else {
            arg = no_arg;
        }
        if (BPOptions[i].default_val) {
            sprintf(defstr, " (Default '%s').", BPOptions[i].default_val);
        } else {
            defstr[0] = '\0';
        }
        if (isascii(BPOptions[i].val)) {
            printf("-%c%s | --%s%s\n\t\t%s%s\n\n",
                   BPOptions[i].val, arg,
                   BPOptions[i].name, arg,
                   BPOptions[i].help, defstr);
        } else {
            printf("--%s%s\n\t\t%s%s\n\n",
                   BPOptions[i].name, arg,
                   BPOptions[i].help, defstr);
        }
    }
    exit(rc);
}

- (BOOL)loadConfigFile:(NSString *)file withError:(NSError **)error{
    NSData *data = [NSData dataWithContentsOfFile:file
                                          options:NSDataReadingMappedIfSafe
                                            error:error];
    if (!data) return FALSE;

    NSDictionary *configDict = [NSJSONSerialization JSONObjectWithData:data
                                                               options:kNilOptions
                                                                 error:error];
    if (!configDict) return FALSE;
    for (NSString *key in configDict) {
        id value = [configDict objectForKey:key];
        for (int i = 0; BPOptions[i].name; i++) {
            if (!strcmp([key UTF8String], BPOptions[i].name)) {

                if (BPOptions[i].kind & BP_LIST && ![value isKindOfClass:[NSArray class]]) {
                    if (error) {
                        *error = [NSError errorWithDomain:BPErrorDomain
                                                     code:-1
                                                 userInfo:@{NSLocalizedDescriptionKey:
                                                                [NSString stringWithFormat:@"Expected type %@ for key '%@', got %@. Parsing failed.",
                                                                 [NSArray className], key, [value className]]}];
                    }
                    return NO;
                }
                if (BPOptions[i].kind & BP_PATH) {
                    NSString *currentPath = [[NSFileManager defaultManager] currentDirectoryPath];
                    if ([value isKindOfClass:[NSArray class]]) {
                        NSMutableArray *newValue = [[NSMutableArray alloc] init];
                        for (NSString *v in value) {
                            if ([v isAbsolutePath]) {
                                [newValue addObject:v];
                            } else {
                                [newValue addObject:[currentPath stringByAppendingPathComponent:v]];
                            }
                        }
                        value = newValue;
                    } else {
                        if (![value isAbsolutePath]) {
                            value = [currentPath stringByAppendingPathComponent:value];
                        }
                    }
                }

                [self setValue:value forKey:[NSString stringWithUTF8String:BPOptions[i].property]];
            }
        }
    }
    return YES;
}

- (BOOL)processOptionsWithError:(NSError **)err {
    // look for a config file first
    BOOL loadedConfig = FALSE;
    for (NSMutableArray *pair in self.cmdLineArgs) {
        NSNumber *op = pair[0];
        NSString *optarg = pair[1];
        if ([op isEqualToNumber:[NSNumber numberWithInt:'c']]) {
            if (loadedConfig) {
                if (err) {
                    NSError *error = [NSError errorWithDomain:BPErrorDomain
                                                         code:-1
                                                     userInfo:@{NSLocalizedDescriptionKey:
                                                                    @"Only one configuration file (-c) allowed."}];
                    *err = error;
                }
                return FALSE;
            }
            // load the config file
            NSError *error;
            if (![self loadConfigFile:optarg withError:&error]) {
                NSError *newError =
                [NSError errorWithDomain:BPErrorDomain
                                    code:-1
                                userInfo:@{ NSLocalizedDescriptionKey:
                                                [NSString stringWithFormat:@"Could not load configuration from %@\n%@",
                                                 optarg, [error localizedDescription]]
                                            }];
                if (err) *err = newError;
                return FALSE;
            }
            loadedConfig = TRUE;
        }
    }

    // Now process options, ignoring config files.
    BOOL printConfig = FALSE;
    for (NSMutableArray *pair in self.cmdLineArgs) {
        NSNumber *op = pair[0];
        NSString *optarg = pair[1];

        // we've already done the config file
        if ([op isEqualToNumber:[NSNumber numberWithInt:'c']]) continue;
        if ([op isEqualToNumber:[NSNumber numberWithInt:'P']]) printConfig = TRUE;

        [self handleOpt:[op intValue] withArg:(char *)[optarg UTF8String]];
    }
    if (printConfig) {
        [self printConfig];
        exit(0);
    }
    [BPUtils quietMode:self.quiet];
    return TRUE;
}

- (BOOL)validateConfigWithError:(NSError *__autoreleasing *)err {
    BOOL isdir;
    if (!self.xcodePath) {
        self.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    }

    if (!self.xcodePath || [self.xcodePath isEqualToString:@""]) {
        if (err) {
            *err = [NSError errorWithDomain:BPErrorDomain
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey: @"Could not set Xcode path!"}];
        }
        return NO;
    }

    if (!self.appBundlePath) {
        if (err) {
            NSDictionary *errInfo = @{ NSLocalizedDescriptionKey : @"No app bundle provided." };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath: self.appBundlePath isDirectory:&isdir] || !isdir) {
        if (err) {
            NSDictionary *errInfo = @{ NSLocalizedDescriptionKey:
                                           [NSString stringWithFormat:@"%@ not found.", self.appBundlePath] };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }
    if (self.outputDirectory) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputDirectory isDirectory:&isdir]) {
            if (!isdir) {
                if (err) *err = [NSError errorWithDomain:BPErrorDomain
                                                    code:-1
                                                userInfo:@{ NSLocalizedDescriptionKey:
                                                                [NSString stringWithFormat:@"%@ is not a directory.",
                                                                 self.outputDirectory] }];
                return NO;
            }
        } else {
            // create the directory
            if (![[NSFileManager defaultManager] createDirectoryAtPath:self.outputDirectory
                                           withIntermediateDirectories:YES
                                                            attributes:nil
                                                                 error:err]) {
                return NO;
            }
        }
        // If we have an output directory, turn on all the bells and whistles
        self.plainOutput = TRUE;
        self.junitOutput = TRUE;
        self.jsonOutput = TRUE;
    }

    if (self.schemePath) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.schemePath isDirectory:&isdir]) {
            if (isdir) {
                if (err) *err = [NSError errorWithDomain:BPErrorDomain
                                                    code:-1
                                                userInfo:@{ NSLocalizedDescriptionKey:
                                                                [NSString stringWithFormat:@"%@ is a directory",
                                                                 self.schemePath]}];
                return NO;
            }
        } else {
            if (err) *err = [NSError errorWithDomain:BPErrorDomain
                                                code:-1
                                            userInfo:@{ NSLocalizedDescriptionKey:
                                                            [NSString stringWithFormat:@"%@ doesn't exist",
                                                             self.schemePath]}];
            return NO;
        }
    } else {
        if (err) *err = [NSError errorWithDomain:BPErrorDomain
                                            code:-1
                                        userInfo:@{NSLocalizedDescriptionKey: @"No scheme provided."}];
        return NO;
    }

    // bp requires an xctest argument while `bluepill` does not.
#ifdef BP_USE_PRIVATE_FRAMEWORKS
    if (!self.testBundlePath) {
        if (err) {
            NSString *desc = NSLocalizedString(@"No test bundle provided.", nil);
            NSDictionary *errInfo = @{ NSLocalizedDescriptionKey : desc };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.testBundlePath isDirectory:&isdir] || !isdir) {
        if (err) {
            NSDictionary *errInfo = @{ NSLocalizedDescriptionKey:
                                           [NSString stringWithFormat:@"%@ not found.", self.testBundlePath] };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }
#endif
    if (!self.deviceType) {
        self.deviceType = [NSString stringWithUTF8String: BP_DEFAULT_DEVICE_TYPE];
    }
    if (!self.runtime) {
        self.runtime = [NSString stringWithUTF8String: BP_DEFAULT_RUNTIME];
    }

#ifdef BP_USE_PRIVATE_FRAMEWORKS
    // Validate we were passed a valid device and runtime
    self.simDeviceType = nil;

    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.xcodePath error: err];
    if (!sc) {
        NSLog(@"Failed to initialize SimServiceContext: %@", *err);
        return NO;
    }

    for (SimDeviceType *type in [sc supportedDeviceTypes]) {
        if ([[type name] isEqualToString:self.deviceType]) {
            self.simDeviceType = type;
            break;
        }
    }

    if (!self.simDeviceType) {
        if (err) {
            NSDictionary *errInfo = @{
                                      NSLocalizedDescriptionKey :
                                          [ NSString stringWithFormat:@"%@ is not a valid device type.\n"
                                           "Use `xcrun simctl list devicetypes` for a list of valid devices.",
                                           self.deviceType] };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }

    self.simRuntime = nil;

    for (SimRuntime *runtime in [sc supportedRuntimes]) {
        if ([[runtime name] isEqualToString:self.runtime]) {
            self.simRuntime = runtime;
            break;
        }
    }

    if (!self.simRuntime) {
        if (err) {
            NSDictionary *errInfo = @{
                                      NSLocalizedDescriptionKey :
                                          [ NSString stringWithFormat:@"%@ is not a valid runtime.\n"
                                           "Use `xcrun simctl list runtimes` for a list of valid runtimes.",
                                           self.runtime] };
            *err = [NSError errorWithDomain:BPErrorDomain code:-1 userInfo:errInfo];
        }
        return NO;
    }
#endif
    return TRUE;
}

- (NSString *)debugDescription {
    return [self configString];
}

- (NSString *)description {
    return [self configString];
}

@end
