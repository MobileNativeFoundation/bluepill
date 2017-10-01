//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "ConfigView.h"
#import "BPXCTestFile.h"
#import "BPTestClass.h"
#import "BPTestCase.h"
#import "CheckboxHeader.h"
#import "BPPrefs.h"

#define BP_EXE          @"bp"
#define BLUEPILL_EXE    @"bluepill"

typedef NS_ENUM(NSInteger, BrowseType) {
    BrowseTypeUnknown,
    BrowseTypeApplication,
    BrowseTypeOutput,
    BrowseTypeTestBundle,
    BrowseTypeXcscheme
};

@interface ConfigView () <NSTableViewDelegate, NSTableViewDataSource, CheckboxHeaderDelegate>

@property (nonatomic, weak) IBOutlet NSComboBox *applicationComboBox;
@property (nonatomic, weak) IBOutlet NSComboBox *outputComboBox;
@property (nonatomic, weak) IBOutlet NSComboBox *testBundleComboBox;
@property (nonatomic, weak) IBOutlet NSComboBox *xcschemeComboBox;
@property (nonatomic, weak) IBOutlet NSButton *applicationBrowseButton;
@property (nonatomic, weak) IBOutlet NSButton *outputBrowseButton;
@property (nonatomic, weak) IBOutlet NSButton *testBundleBrowseButton;
@property (nonatomic, weak) IBOutlet NSButton *xcschemeBrowseButton;

@property (nonatomic, weak) IBOutlet NSTextField *numberOfSimulatorsTextField;

@property (nonatomic, weak) IBOutlet NSTableView *testListTableView;

@property (nonatomic, strong) NSMutableArray<TestItem *> *testList;
@property (nonatomic, strong) NSMutableArray<NSString *> *arguments;
@property (nonatomic, strong) NSTask *task;
@property (nonatomic, weak) CheckboxHeader *checkboxHeader;

@end

@interface CheckboxCellView : NSTableCellView
@property (nonatomic, weak) IBOutlet NSButton *checkbox;
@property (nonatomic, copy) void (^onClickBlock)(void);

- (void)setupTarget;
@end

@interface SimpleClassCellView : NSTableCellView
@end

@interface SimpleTestCellView : NSTableCellView
@end

@implementation ConfigView

- (void)awakeFromNib {
    [super awakeFromNib];

    self.testListTableView.delegate = self;
    self.testListTableView.dataSource = self;

    CheckboxHeader *checkboxHeader = [[CheckboxHeader alloc] init];
    NSTableColumn *runColumn = [self.testListTableView tableColumnWithIdentifier:@"runColumn"];
    [runColumn setHeaderCell:checkboxHeader];
    checkboxHeader.delegate = self;
    self.checkboxHeader = checkboxHeader;

    BPPrefs *prefs = [BPPrefs sharedPrefs];

    [self.applicationComboBox addItemsWithObjectValues:prefs.applicationPaths];
    [self.applicationComboBox setStringValue:prefs.defaultApplicationPath];

    [self.testBundleComboBox addItemsWithObjectValues:prefs.testPaths];
    [self.testBundleComboBox setStringValue:prefs.defaultTestPath];
    [self onTestBundleBrowse:prefs.defaultTestPath];

    [self.xcschemeComboBox addItemsWithObjectValues:prefs.schemePaths];
    [self.xcschemeComboBox setStringValue:prefs.defaultSchemePath];

    [self.outputComboBox addItemsWithObjectValues:prefs.outputPaths];
    [self.outputComboBox setStringValue:prefs.defaultOutputPath];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    // Drawing code here.
}

- (IBAction)onBrowseButton:(id)sender {
    BrowseType browseType = [self typeForButton:sender];
    [self handleBrowseButton:browseType];
}

- (IBAction)onStepper:(id)sender {
    NSStepper *stepper = (NSStepper *)sender;
    if (stepper) {
        [self.numberOfSimulatorsTextField setStringValue:stepper.stringValue];
        if (stepper.integerValue > 16) {
            self.numberOfSimulatorsTextField.textColor = [NSColor redColor];
        } else if (stepper.integerValue > 12) {
            self.numberOfSimulatorsTextField.textColor = [NSColor orangeColor];
        } else {
            self.numberOfSimulatorsTextField.textColor = [NSColor blackColor];
        }
    }
}

- (IBAction)onRunTests:(id)sender {
    BPPrefs *prefs = [BPPrefs sharedPrefs];
    [prefs addApplicationPath:self.applicationComboBox.stringValue];
    [prefs addTestPath:self.testBundleComboBox.stringValue];
    [prefs addSchemePath:self.xcschemeComboBox.stringValue];
    [prefs addOutputPath:self.outputComboBox.stringValue];

    NSURL *executableURL = [[NSBundle mainBundle] executableURL];
    NSLog(@"%@", executableURL);

    NSURL *executableDirURL = [executableURL URLByDeletingLastPathComponent];
    NSLog(@"%@", executableDirURL);

    NSURL *bluepillExecutable = [executableDirURL URLByAppendingPathComponent:BLUEPILL_EXE];

    [self.arguments removeAllObjects];
    [self addArgs:@"-a" withPath:self.applicationComboBox.stringValue];
    [self addArgs:@"-o" withPath:self.outputComboBox.stringValue];
    [self addArgs:@"-t" withPath:self.testBundleComboBox.stringValue];
    [self addArgs:@"-s" withPath:self.xcschemeComboBox.stringValue];
    [self addArgs:@"-n" withValue:self.numberOfSimulatorsTextField.stringValue];

    NSString *fullCommand = [NSString stringWithFormat:@"\"%@\"", [bluepillExecutable path]];
    for (NSString *arg in self.arguments) {
        fullCommand = [fullCommand stringByAppendingString:@" "];
        fullCommand = [fullCommand stringByAppendingString:arg];
    }
    [self runTests:fullCommand];
}

- (void)handleBrowseButton:(BrowseType)browseType {
    NSOpenPanel *selectDialog = [NSOpenPanel openPanel];
    [selectDialog setShowsHiddenFiles:YES];
    [selectDialog setTreatsFilePackagesAsDirectories:NO];

    NSComboBox *combo = nil;
    SEL selector = nil;

    switch (browseType) {
        case BrowseTypeApplication:
            combo = self.applicationComboBox;
            selector = @selector(onApplicationBrowse:);
            [selectDialog setDirectoryURL:[NSURL fileURLWithPath:self.applicationComboBox.stringValue ?: @""]];
            [selectDialog setCanChooseFiles:YES];
            [selectDialog setCanChooseDirectories:NO];
            break;
        case BrowseTypeOutput:
            combo = self.outputComboBox;
            selector = @selector(onOutputBrowse:);
            [selectDialog setDirectoryURL:[NSURL fileURLWithPath:self.outputComboBox.stringValue ?: @""]];
            [selectDialog setCanChooseFiles:NO];
            [selectDialog setCanChooseDirectories:YES];
            break;
        case BrowseTypeTestBundle:
            combo = self.testBundleComboBox;
            selector = @selector(onTestBundleBrowse:);
            [selectDialog setDirectoryURL:[NSURL fileURLWithPath:self.testBundleComboBox.stringValue ?: @""]];
            [selectDialog setTreatsFilePackagesAsDirectories:YES];
            [selectDialog setCanChooseFiles:NO];
            [selectDialog setCanChooseDirectories:YES];
            break;
        case BrowseTypeXcscheme:
            combo = self.xcschemeComboBox;
            selector = @selector(onXcschemeBrowse:);
            [selectDialog setDirectoryURL:[NSURL fileURLWithPath:self.xcschemeComboBox.stringValue ?: @""]];
            [selectDialog setCanChooseFiles:YES];
            [selectDialog setCanChooseDirectories:NO];
            break;
        case BrowseTypeUnknown:
            return;
    }

    if ([selectDialog runModal] == NSModalResponseOK) {
        NSURL *selectedDirectory = [selectDialog directoryURL];
        switch (browseType) {
            case BrowseTypeApplication:
            case BrowseTypeXcscheme:
                selectedDirectory = [selectDialog URL];
                break;
            default:
                break;
        }
        [combo setStringValue:[selectedDirectory path]];
        [self performSelector:selector withObject:[combo stringValue] afterDelay:0];
    }
}

- (BrowseType)typeForButton:(NSButton *)button {
    if (self.applicationBrowseButton == button) {
        return BrowseTypeApplication;
    } else if (self.outputBrowseButton == button) {
        return BrowseTypeOutput;
    } else if (self.testBundleBrowseButton == button) {
        return BrowseTypeTestBundle;
    } else if (self.xcschemeBrowseButton == button) {
        return BrowseTypeXcscheme;
    }
    return BrowseTypeUnknown;
}

- (NSMutableArray<NSString *> *)arguments {
    if (!_arguments) {
        _arguments = [@[] mutableCopy];
    }
    return _arguments;
}

- (void)addArgs:(NSString *)flag withPath:(NSString *)path {
    [self.arguments addObject:flag];
    [self.arguments addObject:[NSString stringWithFormat:@"\"%@\"", path]];
}

- (void)addArgs:(NSString *)flag withValue:(NSString *)value {
    [self.arguments addObject:flag];
    [self.arguments addObject:value];
}

- (void)onApplicationBrowse:(NSString *)path {
    NSLog(@"onApplicationBrowse: %@", path);
}

- (void)onOutputBrowse:(NSString *)path {
    NSLog(@"onOutputBrowse: %@", path);
}

- (void)onTestBundleBrowse:(NSString *)path {
    NSLog(@"onTestBundleBrowse: %@", path);

    if (!path) {
        return;
    }

    NSError *error = nil;
    //TO BE FIXED where do we get the appBundle from?
    BPXCTestFile *testFile = [BPXCTestFile BPXCTestFileFromXCTestBundle:path
                                                       andHostAppBundle:nil
                                                              withError:&error];

    if (error) {
        NSLog(@"%@", [error localizedDescription]);
        return;
    }

    self.testList = [@[] mutableCopy];
    for (BPTestClass *testClass in [testFile testClasses]) {
        for (BPTestCase *testCase in testClass.testCases) {
            TestItem *item = [[TestItem alloc] init];
            item.testClass = testClass.name;
            item.testName = testCase.name;
            item.selected = YES;
            [self.testList addObject:item];
        }
    }

    NSString *tests = @"";
    for (NSString *testCase in [testFile allTestCases]) {
        tests = [tests stringByAppendingFormat:@"%@\n", testCase];
    }
    NSLog(@"%@", tests);

    [self.testListTableView reloadData];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.testList count] > 0) {
            [self.checkboxHeader setCheckboxState:NSOnState];
        }
    });
}

- (void)onXcschemeBrowse:(NSString *)path {
    NSLog(@"onXcschemeBrowse: %@", path);
}

- (NSArray<TestItem *> *)getTestList {
    return [self.testList copy];
}

- (void)runTests:(NSString *)command {
    NSAssert(command, @"Command should not be nil");
    NSTask *task = [NSTask new];
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    NSPipe *pipe = [NSPipe new];
    task.standardError = pipe;
    task.standardOutput = pipe;
    NSFileHandle *fh = pipe.fileHandleForReading;
    NSLog(@"Will run: %@", task.arguments);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onData:) name:NSFileHandleReadCompletionNotification object:fh];
    [fh readInBackgroundAndNotify];

    [task launch];
    self.task = task;

    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_PROC, task.processIdentifier, DISPATCH_PROC_EXIT, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    dispatch_source_set_event_handler(source, ^{
        dispatch_source_cancel(source);
    });
    __block __weak typeof(self) __self = self;
    dispatch_source_set_cancel_handler(source, ^{
        [__self.delegate onConsoleOutput:@"\nFINISHED\n"];
    });
    dispatch_resume(source);
}

- (void)onData:(NSNotification *)notification {
    NSData *data = notification.userInfo[NSFileHandleNotificationDataItem];
    if (data != nil) {
        NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        [self.delegate onConsoleOutput:str];
        NSFileHandle *fh = notification.object;
        [fh readInBackgroundAndNotify];
    }
}

+ (NSString *)runShell:(NSString *)command {
    NSAssert(command, @"Command should not be nil");
    NSTask *task = [NSTask new];
    task.launchPath = @"/bin/sh";
    task.arguments = @[@"-c", command];
    NSPipe *pipe = [NSPipe new];
    task.standardError = pipe;
    task.standardOutput = pipe;
    NSFileHandle *fh = pipe.fileHandleForReading;
    [task launch];
    [task waitUntilExit];
    NSData *data = [fh readDataToEndOfFile];
    return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
}

- (void)checkboxHeader:(CheckboxHeader *)checkboxHeader stateChanged:(NSInteger)newState {
    for (TestItem *item in self.testList) {
        switch (newState) {
            case NSOnState:
                item.selected = YES;
                break;
            case NSOffState:
                item.selected = NO;
                break;
            default:
                break;
        }
    }
    [self.testListTableView reloadData];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *result;
    // Owner for cells from makeWithIdentifier should be nil, or our awakeFromNib will be called again
    TestItem *item = self.testList[row];
    if ([tableColumn.identifier isEqualToString:@"runColumn"]) {
        result = [tableView makeViewWithIdentifier:@"runCell" owner:nil];
        CheckboxCellView *checkboxView = (CheckboxCellView *)result;
        [checkboxView.checkbox setState:item.selected ? NSOnState : NSOffState];
        [checkboxView setupTarget];
        checkboxView.onClickBlock = ^{
            [self onCheckboxClicked:row];
        };
    } else if ([tableColumn.identifier isEqualToString:@"classColumn"]) {
        result = [tableView makeViewWithIdentifier:@"classCell" owner:nil];
        result.textField.stringValue = item.testClass;
    } else if ([tableColumn.identifier isEqualToString:@"testColumn"]) {
        result = [tableView makeViewWithIdentifier:@"testCell" owner:nil];
        result.textField.stringValue = item.testName;
    }
    return result;
}

- (void)onCheckboxClicked:(NSInteger)index {
    TestItem *item = [self.testList objectAtIndex:index];
    item.selected = !item.selected;
    NSLog(@"%d", item.selected);
    BOOL allSame = YES;
    for (TestItem *i in self.testList) {
        if (i.selected != item.selected) {
            allSame = NO;
            break;
        }
    }

    if (!allSame) {
        [self.checkboxHeader setCheckboxState:NSMixedState];
    } else {
        [self.checkboxHeader setCheckboxState:item.selected ? NSOnState : NSOffState];
    }
}

- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
    if ([tableColumn.identifier isEqualToString:@"runColumn"]) {
        CheckboxHeader *checkboxHeader = [tableColumn headerCell];
        [checkboxHeader handleClick];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = 0;
    count += [self.testList count];
    return count;
}

@end

@implementation CheckboxCellView

- (void)setupTarget {
    self.checkbox.target = self;
    self.checkbox.action = @selector(onCheckboxClicked:);
}

- (void)onCheckboxClicked:(id)sender {
    if (self.onClickBlock) {
        self.onClickBlock();
    }
}

@end

@implementation SimpleClassCellView
@end

@implementation SimpleTestCellView
@end

@implementation TestItem
@end
