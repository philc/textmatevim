/*
 * We're using this JSON framework: http://stig.github.com/json-framework/
 */
#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import "CommandModeCursor.h"

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
    NSDictionary * response = [TextMateVimPlugin sendEventRouterMessage:
        [NSDictionary dictionaryWithObjectsAndKeys: @"getKeybindings", @"message", nil]];
    [self removeMenuItemShortcutsWhichMatch: [response objectForKey: @"keybindings"]];
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

/*
 * Override NSWindow's default event handling and add in our own logic.
 * We're going to pass the keystroke event out to the Ruby event handling coprocess, which will determine
 * what to do with it according to the user's VIM mappings.
 */
- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isValidWindowType:self] || [event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  // If we've just changed windows, make sure that our cursor is being rendered in the current window.
  if (self != currentWindow)
    [self setFocusedWindow:self];

  NSDictionary * keydownMessageBody = [NSDictionary dictionaryWithObjectsAndKeys:
      @"keydown", @"message",
      event.charactersIgnoringModifiers, @"characters",
      [NSNumber numberWithInt: event.modifierFlags], @"modifierFlags",
      lineNumber, @"line",
      columnNumber, @"column",
      [NSNumber numberWithBool: [self.oakTextView hasSelection]], @"hasSelection",
      [NSNumber numberWithFloat: [self getScrollPosition: self.oakTextView].y], @"scrollY",
      nil];
      
  NSDictionary * response = [TextMateVimPlugin sendEventRouterMessage: keydownMessageBody];

  // Now that we've sent our keydown message to the Ruby event handler, it will send back a series of
  // editor commands to execute, one at a time. When it's done it will indicate that we should suppress or
  // pass through the current keystroke.
  while (true) {
    // "response" is of the form { "commandName" => [positional arguments] }
    NSString * command = [[response allKeys] objectAtIndex:0];
    if ([command isEqualToString: @"suppressKeystroke"]) {
      return;
    } else if ([command isEqualToString: @"passThroughKeystroke"]) {
      [super sendEvent: event];
      return;
    } else {
      response = [TextMateVimPlugin sendEventRouterMessage: [self handleMessage: response]];
    }
  }
}

/*
 * Handles a message from the Ruby event router. These include methods to forward on to the OakTextView,
 * or methods we'll call directly on this NSWindow.
 * - message: of the form { "commandName" => [positional arguments] }
 */
- (NSDictionary *)handleMessage:(NSDictionary *) message {
  NSString * command = [[message allKeys] objectAtIndex:0];
  NSArray * arguments = [message objectForKey:command];
  
  NSArray * nonTextViewCommands = [NSArray arrayWithObjects:
      @"enterMode:", @"addNewline", @"copySelection", @"paste", @"getClipboardContents",
      @"scrollTo:", @"setSelection:column:", @"undo",
      @"nextTab", @"previousTab", nil];

  NSDictionary * result = NULL;
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
    if ([[invocation methodSignature] methodReturnLength] > 0)
      [invocation getReturnValue:&result];
  }
  else
    // Pass the command on to Textmate's OakTextView.
    [self.oakTextView performSelector: NSSelectorFromString(command) withObject: self];

  return (result == NULL) ? [NSDictionary dictionaryWithObjectsAndKeys: nil] : result;
/*  return [NSDictionary dictionaryWithObjectsAndKeys: nil];*/
}

/*
 * These are commands that the Ruby event handler can invoke.
 */
- (NSDictionary *)getClipboardContents {
  NSString * clipboardContents = [[NSPasteboard generalPasteboard] stringForType:@"NSStringPboardType"];
  return [NSDictionary dictionaryWithObjectsAndKeys: clipboardContents, @"clipboardContents", nil];
}
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

/*
 * Given an array of shortcuts, iterates through all of the submenus in the app's menu bar and disables
 * shortcuts for those menu items which conflict. This is to ensure that TextMateVim's keybindings (in
 * particular CTRL+U) aren't swallowed by Textmate.
 * shortcuts should be an array of the form: [[key, modifier_flags], ...]
 */
- (void)removeMenuItemShortcutsWhichMatch:(NSArray *)shortcuts {
  NSMutableArray * submenus = [NSMutableArray arrayWithCapacity:30];
  [submenus addObject:self.menu];

  while (submenus.count > 0) {
    NSMenu * submenu = [submenus objectAtIndex:0];
    [submenus removeObjectAtIndex:0];

    // NOTE(philc): This is currently O(N^2).
    for (int i = 0; i < submenu.numberOfItems; i++) {
      NSMenuItem * menuItem = [submenu itemAtIndex:i];
      if (menuItem.submenu)
        [submenus addObject: menuItem.submenu];
      for (int j = 0; j < shortcuts.count; j++) {
        NSArray * keystroke = [shortcuts objectAtIndex:j];
        if ([[keystroke objectAtIndex:0] isEqualToString:menuItem.keyEquivalent] &&
            [[keystroke objectAtIndex:1] unsignedIntValue] == menuItem.keyEquivalentModifierMask) {
          [menuItem setKeyEquivalent: @""];
          break;
        }
      }
    }
  }
}

@end