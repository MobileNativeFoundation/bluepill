//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "MainWindowController.h"
#import "ConfigView.h"

@interface MainWindowController ()<ConsoleOutputDelegate, NSDrawerDelegate>
@property (weak) IBOutlet NSToolbarItem *consoleButton;
@property (weak) IBOutlet NSToolbarItem *openConfigButton;
@property (weak) IBOutlet NSToolbarItem *saveConfigButton;
@property (weak) IBOutlet ConfigView *configView;

@property (strong) NSDrawer *drawer;
@property (strong) NSTextView *console;
@end

@implementation MainWindowController

- (instancetype)init {
    self = [super initWithWindowNibName:@"MainWindowController"];
    if (self) {

    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

    self.window.titleVisibility = NSWindowTitleHidden;

    self.consoleButton.action = @selector(onClickConsole:);
    self.openConfigButton.action = @selector(onClickConsole:);
    self.saveConfigButton.action = @selector(onClickConsole:);

    NSSize drawerSize = self.window.contentView.frame.size;
    drawerSize.height -= 20;
    drawerSize.width -= 30;
    self.drawer = [[NSDrawer alloc] initWithContentSize:drawerSize preferredEdge:NSRectEdgeMaxX];
    self.drawer.parentWindow = self.window;

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, drawerSize.width, drawerSize.height)];
    scrollView.borderType = NSLineBorder;
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, drawerSize.width, drawerSize.height)];
    textView.backgroundColor = [NSColor blackColor];
    textView.textColor = [NSColor whiteColor];
    textView.font = [NSFont fontWithName:@"Monaco" size:12.0f];
    textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    textView.horizontallyResizable = YES;
    textView.verticallyResizable = YES;

    scrollView.documentView = textView;
    self.console = textView;
    self.drawer.contentView = scrollView;
//    self.drawer.delegate = self;

    self.configView.delegate = self;
}

- (void)onClickConsole:(id)sender {
    [self.drawer toggle:nil];
}

- (void)onConsoleOutput:(NSString *)output {
    self.console.string = [self.console.string stringByAppendingString:output];
    [self.console scrollRangeToVisible:NSMakeRange([self.console.string length], 0)];
}

- (NSSize)drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize {
    self.console.frame = NSMakeRect(0, 0, contentSize.width, contentSize.height);
    return contentSize;
}

@end
