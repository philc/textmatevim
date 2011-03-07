/*
 * We're using this JSON framework: http://stig.github.com/json-framework/
 */
#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import "CommandModeCursor.h"
#import <JSON/JSON.h>

@implementation TextMateVimWindow

static BOOL firstTimeInitialization = false;
static TextMateVimWindow * currentWindow;
static CommandModeCursor * cursorView;
static NSString * currentMode;
static NSNumber * lineNumber;
static NSNumber * columnNumber;

+ (BOOL)isValidWindowType:(NSWindow *)window {
  return [[window firstResponder] isKindOfClass:NSClassFromString(@"OakTextView")];
}

/*
 * When a different window gets focused, we must add our cursor view to it and register a few bindings.
 */
- (void)setFocusedWindow:(NSWindow *)theWindow {
  if (!firstTimeInitialization) {
    firstTimeInitialization = true;
    [self removeMenuItemShortcuts];
  }
  if (currentWindow != nil) {
    [self.oakTextView unbind:@"lineNumber"];
    [self.oakTextView unbind:@"columnNumber"];
  }

  currentWindow = self;
  currentMode = currentMode ? currentMode : @"insert";

  if (cursorView)
    [cursorView removeFromSuperview];
  cursorView = [[CommandModeCursor alloc] initWithFrame:[self.oakTextView bounds]];
  [self.oakTextView addSubview:cursorView];
  [cursorView setMode:currentMode];

  // NOTE(philc): For some reason these values are only available via binding. There are no methods on
  // OakTextView for lineNumber and columnNumber.
  [self.oakTextView bind:@"lineNumber" toObject:self withKeyPath:@"lineNumber" options:nil];
  [self.oakTextView bind:@"columnNumber" toObject:self withKeyPath:@"columnNumber" options:nil];
}

- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isValidWindowType:self] || [event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  // If we've just changed windows, make sure that our cursor is being rendered in the current window.
  if (self != currentWindow)
    [self setFocusedWindow:self];

  NSDictionary * messageBody = [NSDictionary dictionaryWithObjectsAndKeys:
      event.charactersIgnoringModifiers, @"characters",
      [NSNumber numberWithInt: event.modifierFlags], @"modifierFlags",
      lineNumber, @"line",
      columnNumber, @"column",
      [NSNumber numberWithBool: [self.oakTextView hasSelection]], @"hasSelection",
      [NSNumber numberWithFloat: [self getScrollPosition: self.oakTextView].y], @"scrollY",
      nil];
  NSObject * result = [TextMateVimPlugin sendEventRouterMessage: messageBody];
  if (!result) {
    [super sendEvent: event];
    return;
  }

  NSArray * commands = result;

  NSArray * nonTextViewCommands = [NSArray arrayWithObjects:
      @"enterMode:", @"addNewline", @"copySelection", @"noOp", @"paste",
      @"scrollTo:", @"setSelection:column:", @"undo",
      @"nextTab", @"previousTab", nil];

  if (commands.count > 0) {

    for (int i = 0; i < commands.count; i++) {
      NSString * command = nil;
      NSArray * arguments = nil;
      NSObject * commandStructure = [commands objectAtIndex:i];

      if ([commandStructure isKindOfClass:[NSDictionary class]]) {
        // If this command is a hash, it's on the form { "commandName" => [arguments] }.
        command = [[commandStructure allKeys] objectAtIndex:0];
        arguments = [commandStructure objectForKey:command];
      } else {
        command = (NSString *) commandStructure;
      }
      
      if ([nonTextViewCommands containsObject:command]) {
        // NSInvocation is necessary to handle calling methods with an arbitrary number of arguments.
        NSMethodSignature * methodSignature =
            [[self class] instanceMethodSignatureForSelector:NSSelectorFromString(command)];
        NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        [invocation setTarget:self];
        [invocation setSelector:NSSelectorFromString(command)];
        if (arguments) {
          for (int i = 0; i < arguments.count; i++) { 
            NSObject * arg = [arguments objectAtIndex:i];
            [invocation setArgument:&arg atIndex:i + 2];
          }
        }

        [invocation invoke];
      }
      else
        // Pass the command on to Textmate's OakTextView.
        [self.oakTextView performSelector: NSSelectorFromString(command) withObject: self];
    }
  } else {
    [super sendEvent: event];
  }
}

/*
 * These are commands that the Ruby event handler can invoke.
 */
- (void)noOp { }

- (void)paste {
  // readSelectionFromPasteboard will replace whatever's currently selected.
  [self.oakTextView readSelectionFromPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)setSelection:(NSNumber *)line column:(NSNumber *)column {
  [self.oakTextView selectToLine:line andColumn:column];
}

/* Scrolls the OakTextView to the given Y coordinate. TODO(philc): Support X as well. */
- (void)scrollTo:(NSNumber *)y {
  NSPoint scrollPosition = [self getScrollPosition: (NSView *)self.oakTextView];
  scrollPosition.y = y.floatValue;
  [self.oakTextView scrollPoint: scrollPosition];
}

- (void)addNewline { [self.oakTextView insertText:@"\n"]; }

/* NOTE(philc): I'm not sure what this argument is supposed to be to undo, but using 0 causes the last
 * action to be undone, which is precisely what we need. */
- (void)undo { [self.oakTextView undo:0]; }

- (void)enterMode:(NSString *)mode {
  currentMode = mode;
  if (cursorView)
    [cursorView setMode: mode];
}

- (void)nextTab {
  id tabBar = self.oakTabBarView;
  if (tabBar)
    [tabBar selectNextTab:nil];
}

- (void)previousTab {
  id tabBar = self.oakTabBarView;
  if (tabBar)
    [tabBar selectPreviousTab:nil];
}

- (void)copySelection {
  [self.oakTextView writeSelectionToPasteboard:[NSPasteboard generalPasteboard]
      types:[NSArray arrayWithObject:@"NSStringPboardType"]];
}

- (NSNumber *)lineNumber { return lineNumber; }
- (NSNumber *)columnNumber { return columnNumber; }

- (void)setLineNumber:(id)theLineNumber {
  if (lineNumber)
    [lineNumber release];
  lineNumber = theLineNumber;
  [lineNumber retain];
}
- (void)setColumnNumber:(id)theColumnNumber {
  if (columnNumber)
    [columnNumber release];
  columnNumber = theColumnNumber;
  [columnNumber retain];
}

/* For the given NSView, retrieves its scroll position. */
- (NSPoint)getScrollPosition:(NSView *)view { return view.enclosingScrollView.documentVisibleRect.origin; }

// OakTextView is Textmate's text editor implementation.
- (NSView *)oakTextView { return (NSView *)self.firstResponder; }

// The TabBarView which controls the tabs for the current window. nil if only a single file is being edited.
- (id)oakTabBarView {
  NSView * current = self.oakTextView;
  while (current && current.superview &&
      ![current.superview isKindOfClass:NSClassFromString(@"NSThemeFrame")])
    current = current.superview;
  if (!current)
    return nil;
  for (int i = 0; i < current.subviews.count; i++) {
    id subview = [current.subviews objectAtIndex:i];
    if ([subview isKindOfClass:NSClassFromString(@"OakTabBarView")])
      return subview;
  }
  return nil;
}

- (void)removeMenuItemShortcuts {
  NSMutableArray * submenus = [NSMutableArray arrayWithCapacity: 30];
  [submenus addObject:self.menu];

  while (submenus.count > 0) {
    NSMenu * submenu = [submenus objectAtIndex:0];
    [submenus removeObjectAtIndex:0];

    for (int i = 0; i < submenu.numberOfItems; i++) {
      NSMenuItem * menuItem = [submenu itemAtIndex: i];
      if (menuItem.submenu)
        [submenus addObject: menuItem.submenu];

      if ([menuItem.title isEqualToString: @"to Uppercase"])
        [menuItem setKeyEquivalent: @""];
    }
  }
}

@end