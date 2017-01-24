//  Copyright 2016 LinkedIn Corporation
//  Licensed under the BSD 2-Clause License (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at https://opensource.org/licenses/BSD-2-Clause
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OF ANY KIND, either express or implied.  See the License for the specific language governing permissions and limitations under the License.

#import "CheckboxHeader.h"

@interface CheckboxHeader()
@property (nonatomic, strong) NSButtonCell *checkbox;
@end

@implementation CheckboxHeader

- (instancetype)init {
    self = [super init];

    if (self) {
        [self setTitle:@""];

        self.checkbox = [[NSButtonCell alloc] init];
        [self.checkbox setButtonType:NSButtonTypeSwitch];
        [self.checkbox setControlSize:self.controlSize];
        [self.checkbox setTitle:@""];
        [self.checkbox setImagePosition:NSImageLeft];
        [self.checkbox setAllowsMixedState:YES];
    }
    return self;
}

- (void)handleClick {
    NSInteger newState = self.checkbox.state;
    switch (self.checkbox.state) {
        case NSOnState:
        case NSMixedState:
            newState = NSOffState;
            break;
        case NSOffState:
            newState = NSOnState;
            break;
    }
    self.checkbox.state = newState;
    [self.delegate checkboxHeader:self stateChanged:newState];
}

- (void)setCheckboxState:(NSInteger)state {
    self.checkbox.state = state;
    [self.delegate checkboxHeader:self stateChanged:state];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [self.checkbox drawWithFrame:cellFrame inView:controlView];
}

@end
