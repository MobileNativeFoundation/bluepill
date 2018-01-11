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
#import "BPVersion.h"
#import <getopt.h>
#import <objc/runtime.h>
#import "BPConstants.h"

typedef NS_OPTIONS(NSUInteger, BPOptionType) {
    BP_VALUE = 1, // Single value
    BP_LIST = 1 << 1, // List value
    BP_PATH = 1 << 2, // Single value, CWD will be prepended
    BP_BOOL = 1 << 3, // Boolean value
    BP_INTEGER = 1 << 4, // Integer value
};

// This data structure is shared between `bp` and `bluepill` to keep the
// arguments consistent and also make it easier to share config files
// between the two.
struct BPOptions {
    int          val;          // short option (e.g. -f)
    const char   *name;        // long name of the option (e.g. --foobar)
    int          program;      // BP_MASTER, BP_SLAVE, or both (BP_MASTER | BP_SLAVE)
    BOOL         required;     // Whether the option is required or optional
    BOOL         seen;         // Whether we've seen the option in processing.
    int          has_arg;      // One of: no_argument, required_argument, optional_argument
    const char   *default_val; // Default value (if option not provided)
    BPOptionType kind;         // List vs value.
    const char   *property;    // Which class property to set (via KVO)
    const char   *help;        // Help string, what the option does.
} BPOptions[] = {

    // Required argument
    {'a', "app", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "appBundlePath",
        "The path to the host application to execute (your .app)"},
    {'s', "scheme-path", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "schemePath",
        "The scheme to run tests."},

    // Required arguments for ui testing
    {'u', "runner-app-path", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "testRunnerAppPath",
        "The test runner for UI tests."},

    // Optional argument
    {'d', "device", BP_MASTER | BP_SLAVE, NO, NO, required_argument, BP_DEFAULT_DEVICE_TYPE, BP_VALUE, "deviceType",
        "On which device to run the app."},
    {'c', "config", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE, "configFile",
        "Read options from the specified configuration file instead of the command line"},
    {'t', "test-bundle-path", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "testBundlePath",
        "The test bundle to run tests."},
    {'C', "repeat-count", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "1", BP_VALUE | BP_INTEGER, "repeatTestsCount",
        "Number of times we'll run the entire test suite (used for stability testing)."},
    {'N', "no-split", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST, "noSplit",
        "A list of NO split test bundles"},
    {'P', "print-config", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "stdout", BP_VALUE, "configOutputFile",
        "Print a configuration file suitable for passing back using the `-c` option."},
    {'R', "error-retries", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "4", BP_VALUE | BP_INTEGER, "errorRetriesCount",
        "Number of times we'll recover from crashes to continue running the current test suite."},
    {'S', "stuck-timeout", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "300", BP_VALUE | BP_INTEGER, "stuckTimeout",
        "Timeout in seconds for a test that seems stuck (no output)."},
    {'T', "test-timeout", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "300", BP_VALUE | BP_INTEGER, "testCaseTimeout",
        "Timeout in seconds for a test that is producing output."},
    {'f', "failure-tolerance", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "0", BP_VALUE | BP_INTEGER, "failureTolerance",
        "The number of retries on any failures (app crash/test failure)."},
    {'i', "include", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST, "testCasesToRun",
        "Include a testcase in the set of tests to run (unless specified in `exclude`)."},
    {'n', "num-sims", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "4", BP_VALUE | BP_INTEGER, "numSims",
        "Number of simulators to run in parallel. (bluepill only)"},
    {'o', "output-dir", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "outputDirectory",
        "Directory where to put output log files (bluepill only)."},
    {'r', "runtime", BP_MASTER | BP_SLAVE, NO, NO, required_argument, BP_DEFAULT_RUNTIME, BP_VALUE, "runtime",
        "What runtime to use."},
    {'x', "exclude", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST, "testCasesToSkip",
        "Exclude a testcase in the set of tests to run (takes priority over `include`)."},
    {'X', "xcode-path", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "xcodePath",
        "Path to xcode."},
    {'u', "simulator-udid", BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE, "useSimUDID",
        "Do not create a simulator but reuse the one with the UDID given. (BP INTERNAL USE ONLY). "},
    {'D', "delete-simulator", BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE, "deleteSimUDID",
        "The device UUID of simulator to delete. Using this option enables a DELETE-ONLY-MODE. (BP INTERNAL USE ONLY). "},
    {'V', "video-paths", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST | BP_PATH, "videoPaths",
        "Paths to the videos to be uploaded."},
    {'I', "image-paths", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST | BP_PATH, "imagePaths",
        "Paths to the images to be uploaded."},

    // options with no argument
    {'H', "headless", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL , "headlessMode",
        "Run in headless mode (no GUI)."},
    {'J', "json-output", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "jsonOutput",
        "Print test timing information in JSON format."},
    {'h', "help", BP_MASTER | BP_SLAVE, NO, NO, no_argument, NULL, BP_VALUE, NULL,
        "This help."},
    {'p', "plain-output", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "plainOutput",
        "Print results in plain text."},
    {'q', "quiet", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "quiet",
        "Turn off all output except fatal errors."},
    {'j', "junit-output", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "junitOutput",
        "Print results in JUnit format."},
    {'F', "only-retry-failed", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "onlyRetryFailed",
        "If `failure-`tolerance` is > 0, only retry tests that failed."},
    {'l', "list-tests", BP_MASTER, NO, NO, no_argument, NULL, BP_VALUE | BP_BOOL, "listTestsOnly",
        "Only list tests in bundle"},
    {'v', "verbose", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "verboseLogging",
        "Enable verbose logging"},

    // options without short-options
    {349, "additional-unit-xctests", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST | BP_PATH, "additionalUnitTestBundles",
        "Additional XCTest bundles to test."},
    {350, "additional-ui-xctests", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_LIST | BP_PATH, "additionalUITestBundles",
        "Additional XCUITest bundles to test."},
    {351, "reuse-simulator", BP_MASTER, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "reuseSimulator",
        "Enable reusing simulators between test bundles"},
    {352, "keep-simulator", BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "keepSimulator",
        "Don't delete the simulator device after one test bundle finish. (BP INTERNAL USE ONLY). "},
    {353, "max-sim-create-attempts", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "2", BP_VALUE | BP_INTEGER, "maxCreateTries",
        "The maximum number of times to attempt to create a simulator before failing a test attempt"},
    {354, "max-sim-install-attempts", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "2", BP_VALUE | BP_INTEGER, "maxInstallTries",
        "The maximum number of times to attempt to install the test app into a simulator before failing a test attempt"},
    {355, "max-sim-launch-attempts", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "2", BP_VALUE | BP_INTEGER, "maxLaunchTries",
        "The maximum number of times to attempt to launch the test app in a simulator before failing a test attempt"},
    {356, "create-timeout", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "300", BP_VALUE | BP_INTEGER, "createTimeout",
        "The maximum amount of time, in seconds, to wait before giving up on simulator creation"},
    {357, "launch-timeout", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "300", BP_VALUE | BP_INTEGER, "launchTimeout",
        "The maximum amount of time, in seconds, to wait before giving up on application launch in the simulator"},
    {358, "delete-timeout", BP_MASTER | BP_SLAVE, NO, NO, required_argument, "300", BP_VALUE | BP_INTEGER, "deleteTimeout",
        "The maximum amount of time, in seconds, to wait before giving up on simulator deletion"},

    // New options
    {359, "xctestrun-path", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "xcTestRunPath",
        "The .xctestrun file with test information."},
    {360, "diagnostics", BP_MASTER | BP_SLAVE, NO, NO, no_argument, "Off", BP_VALUE | BP_BOOL, "saveDiagnosticsOnError",
        "Save Simulator diagnostics and useful debugging information in the output directory. If no output directory it doesn't do anything."},
    {361, "screenshots-directory", BP_MASTER | BP_SLAVE, NO, NO, required_argument, NULL, BP_VALUE | BP_PATH, "screenshotsDirectory",
        "Directory where simulator screenshots for failed ui tests will be stored"},

    {0, 0, 0, 0, 0, 0, 0}
};

static NSUUID *sessionID;

@implementation BPConfiguration

#pragma mark instance methods

- (instancetype)initWithProgram:(int)program {
    return [self initWithConfigFile:nil forProgram:program withError:nil];
}

- (instancetype)initWithConfigFile:(NSString *)file forProgram:(BPProgram)program withError:(NSError **)err {
    self = [super init];
    if (program != BP_MASTER && program != BP_SLAVE) return nil;
    self.program = program;
    self.bpCmdLineArgs = [[NSMutableArray alloc] init];
    // set factory defaults
    if (!sessionID) {
        sessionID = [NSUUID UUID];
    }
    self.sessionIdentifier = sessionID;
    for (int i = 0; BPOptions[i].name; i++) {
        if (!(BPOptions[i].program & self.program)) {
            continue;
        }
        if (BPOptions[i].default_val) {
            [self handleOpt:BPOptions[i].val withArg:(char *)BPOptions[i].default_val];
        }
        // Since we're reinitializing, we haven't seen any options
        BPOptions[i].seen = NO;
    }
    if (!file || [self loadConfigFile:file withError:err]) {
        return self;
    }
    return nil;
}

- (void)saveOpt:(NSNumber *)opt withArg:(NSString *)arg {
    [self.bpCmdLineArgs addObject:@[opt, arg]];
}

- (void)handleOpt:(int)opt withArg:(char *)arg {
    struct BPOptions *bpo = NULL;

    for (int i = 0; BPOptions[i].name; i++) {
        if (!(BPOptions[i].program & self.program)) {
            continue;
        }
        if (BPOptions[i].val == opt) {
            bpo = &BPOptions[i];
            break;
        }
    }
    if (bpo == NULL) {
        // The error has already been printed in the call to getopt_long().
        exit(1);
    }
    assert(bpo && bpo->name);
    if (!strcmp(bpo->name, "help")) [self usage:0];
    bpo->seen = YES;
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
            if (bpo->kind & BP_INTEGER) {
                [self setValue:@([value integerValue]) forKey:propName];
            } else {
                [self setValue:value forKey:propName];
            }
        }
    } else if (bpo->kind & BP_LIST) {
        id listValue = value;

        if (bpo->kind & BP_INTEGER) {
            listValue = @([value integerValue]);
        }

        NSString *property = [NSString stringWithUTF8String:bpo->property];
        NSMutableArray *a = [self valueForKey:property];
        if (a) {
            [a addObject:listValue];
        } else {
            NSMutableArray *a = [[NSMutableArray alloc] initWithArray:@[listValue]];
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
    if (self.commandLineArguments) {
        [dict setValue:self.commandLineArguments forKey:@"commandLineArguments"];
    }
    if (self.environmentVariables) {
        [dict setValue:self.environmentVariables forKey:@"environmentVariables"];
    }
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *err;
        NSData *json = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&err];
        if (!json) {
            [BPUtils printInfo:ERROR withString:@"%@", err];
            return nil;
        }
        NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
        return jsonString;
    } else {
        [BPUtils printInfo:ERROR withString:@"Error: configuration not serializable."];
    }
    return nil;
}

-(id)copyWithZone:(NSZone *)zone {
    // gross
    return [self mutableCopyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    BPConfiguration *newConfig = [[BPConfiguration alloc] initWithProgram:self.program];
    assert(newConfig);
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
    newConfig.testing_Environment = self.testing_Environment;
    newConfig.xcTestRunPath = self.xcTestRunPath;
    newConfig.xcTestRunDict = self.xcTestRunDict;
    newConfig.commandLineArguments = self.commandLineArguments;
    newConfig.environmentVariables = self.environmentVariables;

    return newConfig;
}

- (struct option *)getLongOptions {
    struct option *opt = {0};
    int i, j;
    for (i = 0; BPOptions[i].name; i++) {}
    opt = malloc(sizeof(struct option) * (i + 1));
    assert(opt);
    for (i = 0, j = 0; BPOptions[i].name; i++) {
        if (!(BPOptions[i].program & self.program)) {
            continue;
        }
        opt[j].name = BPOptions[i].name;
        opt[j].has_arg = BPOptions[i].has_arg;
        opt[j].flag = NULL;
        opt[j].val = BPOptions[i].val;
        j++;
    }
    opt[j].name = NULL;
    opt[j].has_arg = 0;
    opt[j].flag = NULL;
    opt[j].val = 0;
    return opt;
}

- (char *)getShortOptions {
    char *opt;
    int i, j;
    for (i = 0; BPOptions[i].name; i++) {}
    opt = malloc(i * 2 + 1);
    for (i = 0, j = 0; BPOptions[i].name; i++) {
        if (!(BPOptions[i].program & self.program)) {
            continue;
        }
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
        if (!(BPOptions[i].program & self.program)) {
            continue;
        }
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
                    BP_SET_ERROR(error, @"Expected type %@ for key '%@', got %@. Parsing failed.",
                                          [NSArray className], key, [value className]);
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
                BPOptions[i].seen = YES;
            }
        }
    }
    // Pull out two keys that are undocumented but needed for supporting xctest
    self.commandLineArguments = [configDict objectForKey:@"commandLineArguments"];
    self.environmentVariables = [configDict objectForKey:@"environmentVariables"];
    return YES;
}

- (BOOL)processOptionsWithError:(NSError **)err {
    // look for a config file first
    BOOL loadedConfig = FALSE;
    for (NSMutableArray *pair in self.bpCmdLineArgs) {
        NSNumber *op = pair[0];
        NSString *optarg = pair[1];
        if ([op isEqualToNumber:[NSNumber numberWithInt:'c']]) {
            if (loadedConfig) {
                BP_SET_ERROR(err, @"Only one configuration file (-c) allowed.");
                return FALSE;
            }
            // load the config file
            NSError *error;
            if (![self loadConfigFile:optarg withError:&error]) {
                BP_SET_ERROR(err, @"Could not load configuration from %@\n%@", optarg, [error localizedDescription]);
                return FALSE;
            }
            loadedConfig = TRUE;
        }
    }

    // Now process options, ignoring config files.
    BOOL printConfig = FALSE;
    for (NSMutableArray *pair in self.bpCmdLineArgs) {
        NSNumber *op = pair[0];
        NSString *optarg = pair[1];

        // we've already done the config file
        if ([op isEqualToNumber:[NSNumber numberWithInt:'c']]) continue;
        if ([op isEqualToNumber:[NSNumber numberWithInt:'P']]) printConfig = TRUE;

        [self handleOpt:[op intValue] withArg:(char *)[optarg UTF8String]];
    }
    // Now check we didn't miss any require options:
    NSMutableArray *errors = [[NSMutableArray alloc] init];
    if (!(self.appBundlePath && self.schemePath) && !(self.xcTestRunPath) && !(self.deleteSimUDID)) {
        [errors addObject:@"Missing required option: -a/--app and -s/--scheme-path OR --xctestrun-path"];
    }
    if ((self.program & BP_SLAVE) && !(self.testBundlePath) && !(self.deleteSimUDID)) {
        [errors addObject:@"Missing required option: -t/--test-bundle-path"];
    }
    if (errors.count > 0) {
        BP_SET_ERROR(err, [errors componentsJoinedByString:@"\n\t"]);
        return FALSE;
    }
    if (printConfig) {
        [self printConfig];
        exit(0);
    }
    return TRUE;
}

// Validate that the xctestrun file used is in a valid format and fill in the parsed dictionary.
// See `man xcodebuild.xctestrun` for info about the file.
- (BOOL)parseXcTestRunFile:(NSString *)path withError:(NSError *__autoreleasing *)error {
    BOOL isdir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir] || isdir) {
        BP_SET_ERROR(error, @"Failed to find file %@", path);
        return NO;
    }
    NSData *plistData = [[NSMutableData alloc] initWithContentsOfFile:path];
    if (plistData == nil) {
        BP_SET_ERROR(error, @"Failed to open file %@", path);
        return NO;
    }
    NSMutableDictionary* plist = [NSPropertyListSerialization propertyListWithData:plistData
                                                                           options: NSPropertyListImmutable
                                                                            format:NULL
                                                                             error:error];
    if (plist == nil) {
        BP_SET_ERROR(error, @"Could not parse plist format from %@: %@", path, [*error localizedDescription]);
        return NO;
    }
    self.xcTestRunDict = plist;
    return YES;
}

- (BOOL)parseXcSchemeFile:(NSString *)schemePath withError:(NSError *__autoreleasing *)error {
    NSMutableArray<NSString *> *commandLineArgs  = [NSMutableArray new];
    NSMutableDictionary<NSString *, NSString *> *environmentVariables = [NSMutableDictionary new];
    
    NSData *xmlData = [[NSMutableData alloc] initWithContentsOfFile:schemePath];
    if (xmlData) {
        NSXMLDocument *document = [[NSXMLDocument alloc] initWithData:xmlData options:0 error:error];
        if (!document) {
            BP_SET_ERROR(error, @"Failed to parse scheme file at %@: %@", schemePath, [*error localizedDescription]);
            return NO;
        }
        NSArray *argsNodes = [document nodesForXPath:[NSString stringWithFormat:@"//%@//CommandLineArgument", @"LaunchAction"] error:error];
        NSMutableArray *envNodes = [[NSMutableArray alloc] init];
        [envNodes addObjectsFromArray:[document nodesForXPath:[NSString stringWithFormat:@"//%@//EnvironmentVariable", @"LaunchAction"] error:error]];
        [envNodes addObjectsFromArray:[document nodesForXPath:[NSString stringWithFormat:@"//%@//EnvironmentVariable", @"TestAction"] error:error]];
        for (NSXMLElement *node in argsNodes) {
            NSString *argument = [[node attributeForName:@"argument"] stringValue];
            if (![[[node attributeForName:@"isEnabled"] stringValue] boolValue]) {
                continue;
            }
            NSArray *argumentsArray = [argument componentsSeparatedByString:@" "];
            for (NSString *arg in argumentsArray) {
                if (![arg isEqualToString:@""]) {
                    [commandLineArgs addObject:arg];
                }
            }
        }
        
        for (NSXMLElement *node in envNodes) {
            NSString *key = [[node attributeForName:@"key"] stringValue];
            NSString *value = [[node attributeForName:@"value"] stringValue];
            if ([[[node attributeForName:@"isEnabled"] stringValue] boolValue]) {
                environmentVariables[key] = value;
            }
            
        }
    }
    self.commandLineArguments = commandLineArgs;
    self.environmentVariables = environmentVariables;
    return YES;
}



- (BOOL)validateConfigWithError:(NSError *__autoreleasing *)err {
    BOOL isdir;
    if (!self.xcodePath) {
        self.xcodePath = [BPUtils runShell:@"/usr/bin/xcode-select -print-path"];
    }

    if (!self.xcodePath || [self.xcodePath isEqualToString:@""]) {
        BP_SET_ERROR(err, @"Could not set Xcode path!");
        return NO;
    }

    if (![[NSFileManager defaultManager] fileExistsAtPath:self.xcodePath isDirectory:&isdir] || !isdir) {
        BP_SET_ERROR(err, @"Could not find Xcode at %@", self.xcodePath);
        return NO;
    }
    
    //Check if xcode version running on the host match the intended Bluepill branch: Xcode 9 branch is not backward compatible
    NSString *xcodeVersion = [BPUtils runShell:@"xcodebuild -version"];
    if ([xcodeVersion rangeOfString:@BP_DEFAULT_XCODE_VERSION].location == NSNotFound) {
        BP_SET_ERROR(err, @"ERROR: Invalid Xcode version:\n%s;\nOnly %s is supported\n", [xcodeVersion UTF8String], BP_DEFAULT_XCODE_VERSION);
        return NO;
    }
    
    //Check if Bluepill compile time Xcode version is matched with Bluepill runtime Xcode version
    //Senario to prevent: Bluepill is compiled with Xcode 8, but runs with host installed with Xcode 9
    //Only compare major and minor version version Exg. 9.1 == 9.1
    if (![[[BPUtils getXcodeRuntimeVersion] substringToIndex:3] isEqualToString:[@XCODE_VERSION substringToIndex:3]]) {
        BP_SET_ERROR(err, @"ERROR: Bluepill runtime version %s and compile time version %s are mismatched\n",
                     [[[BPUtils getXcodeRuntimeVersion] substringToIndex:3] UTF8String], [[@XCODE_VERSION substringToIndex:3] UTF8String]);
        return NO;
    }

    if (self.deleteSimUDID) {
        return YES;
    }

    if (self.xcTestRunPath && ![self parseXcTestRunFile:self.xcTestRunPath withError:err]) {
            return NO;
    }

    if (!self.appBundlePath && !self.xcTestRunDict) {
        BP_SET_ERROR(err, @"No app bundle provided.");
        return NO;
    }

    if (self.appBundlePath && (![[NSFileManager defaultManager] fileExistsAtPath: self.appBundlePath isDirectory:&isdir] || !isdir)) {
        BP_SET_ERROR(err, @"%@ not found.", self.appBundlePath);
        return NO;
    }
    NSString *path = [self.appBundlePath stringByAppendingPathComponent:@"Info.plist"];
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (!dic) {
        BP_SET_ERROR(err, @"Could not read %@, perhaps you forgot to run xcodebuild build-for-testing?", path);
    }

    NSString *platform = [dic objectForKey:@"DTPlatformName"];
    if (platform && ![platform isEqualToString:@"iphonesimulator"]) {
        BP_SET_ERROR(err, @"Wrong platform in %@. Expected 'iphonesimulator', found '%@'", self.appBundlePath, platform);
        return NO;
    }

    if (self.outputDirectory) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.outputDirectory isDirectory:&isdir]) {
            if (!isdir) {
                BP_SET_ERROR(err, @"%@ is not a directory.", self.outputDirectory);
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

    if (self.screenshotsDirectory) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.screenshotsDirectory isDirectory:&isdir]) {
            if (!isdir) {
                BP_SET_ERROR(err, @"%@ is not a directory.", self.screenshotsDirectory);
                return NO;
            }
        } else {
            // create the directory
            if (![[NSFileManager defaultManager] createDirectoryAtPath:self.screenshotsDirectory
                                           withIntermediateDirectories:YES
                                                            attributes:nil
                                                                 error:err]) {
                return NO;
            }
        }
    }

    if (!self.xcTestRunDict && self.schemePath) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:self.schemePath isDirectory:&isdir]) {
            if (isdir) {
                BP_SET_ERROR(err, @"%@ is a directory", self.schemePath);
                return NO;
            }
        } else {
            BP_SET_ERROR(err, @"%@ doesn't exist", self.schemePath);
            return NO;
        }
        if (![self parseXcSchemeFile:self.schemePath withError:err]) {
            return NO;
        }
        [BPUtils printInfo:WARNING withString:@"The --scheme-path option is broken and is being deprecated. Please switch to using --xctestrun-path."];
    } else if (!_xcTestRunDict) {
        BP_SET_ERROR(err, @"No scheme provided.");
        return NO;
    }

    // bp requires an xctest argument while `bluepill` does not.
#ifdef BP_USE_PRIVATE_FRAMEWORKS
    if (!self.testBundlePath) {
        BP_SET_ERROR(err, @"No test bundle provided.");
        return NO;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.testBundlePath isDirectory:&isdir] || !isdir) {
        BP_SET_ERROR(err, @"%@ not found.", self.testBundlePath);
        return NO;
    }
#endif
    if (!self.deviceType) {
        self.deviceType = [NSString stringWithUTF8String: BP_DEFAULT_DEVICE_TYPE];
    }

    if (![self.deviceType isKindOfClass:[NSString class]]) {
        BP_SET_ERROR(err, @"device must be a string like '%s'", BP_DEFAULT_DEVICE_TYPE);
        return NO;
    }

    if (!self.runtime) {
        self.runtime = [NSString stringWithUTF8String: BP_DEFAULT_RUNTIME];
    }

    if (![self.runtime isKindOfClass:[NSString class]]) {
        BP_SET_ERROR(err, @"runtime must be a string like '%s'.", BP_DEFAULT_RUNTIME);
        return NO;
    }


#ifdef BP_USE_PRIVATE_FRAMEWORKS
    // Validate we were passed a valid device and runtime
    self.simDeviceType = nil;

    SimServiceContext *sc = [SimServiceContext sharedServiceContextForDeveloperDir:self.xcodePath error: err];
    if (!sc) {
        [BPUtils printInfo:ERROR withString:@"Failed to initialize SimServiceContext: %@", *err];
        [BPUtils printInfo:ERROR withString:@"self.xcodePath is: %@", self.xcodePath];
        return NO;
    }

    for (SimDeviceType *type in [sc supportedDeviceTypes]) {
        if ([[type name] isEqualToString:self.deviceType]) {
            self.simDeviceType = type;
            break;
        }
    }

    if (!self.simDeviceType) {
        BP_SET_ERROR(err, @"%@ is not a valid device type.\n"
                     "Use `xcrun simctl list devicetypes` for a list of valid devices.",
                     self.deviceType);
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
        BP_SET_ERROR(err, @"%@ is not a valid runtime.\n"
                     "Use `xcrun simctl list runtimes` for a list of valid runtimes.",
                     self.runtime);
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
