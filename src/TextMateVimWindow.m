#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import "CommandModeCursor.h"

@implementation TextMateVimWindow

static BOOL firstTimeInitialization = false;

static TextMateVimWindow * currentWindow;
// The view which draws the vim-style block cursor.
static CommandModeCursor * cursorView;
static NSString * currentMode;
static NSNumber * lineNumber;
static NSNumber * columnNumber;
static NSDictionary * menuItemsByTitle;

/*
 * We only want to intercept events for windows which contain the text editing view.
 */
+ (BOOL)isEditorWindow:(NSWindow *)window {
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
    NSArray * menuItems = [self menuItemsList];
    [self removeMenuItemShortcutsWhichMatch: [response objectForKey: @"keybindings"] menuItems:menuItems];
    menuItemsByTitle = [[self getMenuItemsByTitle:menuItems] retain];
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
 * what to do with it according to the user's modal keymappings.
 */
- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isEditorWindow:self] || event.type != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  // If we've just changed windows, make sure that our cursor is being rendered in the current window.
  if (self != currentWindow)
    [self setFocusedWindow:self];

  NSPoint scrollPosition = [self getScrollPosition:self.oakTextView];
  NSDictionary * keydownMessageBody = [NSDictionary dictionaryWithObjectsAndKeys:
      @"keydown", @"message",
      event.charactersIgnoringModifiers, @"characters",
      [NSNumber numberWithInt:event.modifierFlags], @"modifierFlags",
      lineNumber, @"line",
      columnNumber, @"column",
      [NSNumber numberWithBool:[self.oakTextView hasSelection]], @"hasSelection",
      [NSNumber numberWithFloat:scrollPosition.x], @"scrolly",
      [NSNumber numberWithFloat:scrollPosition.y], @"scrollY",
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
- (NSDictionary *)handleMessage:(NSDictionary *)message {
  NSString * command = [[message allKeys] objectAtIndex:0];
  NSArray * arguments = [message objectForKey:command];
  
  NSArray * textMateVimWindowCommands = [NSArray arrayWithObjects:
      @"enterMode:", @"addNewline", @"copySelection", @"paste", @"hasSelection", @"selectNone",
      @"getSelectedText", @"getClipboardContents", @"setClipboardContents:",
      @"scrollTo:y:", @"setSelection:column:", @"undo",
      @"clickMenuItem:", nil];

  NSDictionary * result = NULL;
  if ([textMateVimWindowCommands containsObject:command]) {
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
    // Pass the command on to TextMate's OakTextView.
    [self.oakTextView performSelector: NSSelectorFromString(command) withObject:self];

  return (result == NULL) ? [NSDictionary dictionaryWithObjectsAndKeys:nil] : result;
}

/*
 * These are commands that the Ruby event handler can invoke.
 */
- (NSDictionary *)getClipboardContents {
  NSString * clipboardContents = [[NSPasteboard generalPasteboard] stringForType:@"NSStringPboardType"];
  return [NSDictionary dictionaryWithObjectsAndKeys:clipboardContents, @"clipboardContents", nil];
}

- (void)setClipboardContents:(NSString *)contents {
  [[NSPasteboard generalPasteboard] setString:contents forType:@"NSStringPboardType"];
}

- (void)paste {
  // readSelectionFromPasteboard will replace whatever's currently selected.
  [self.oakTextView readSelectionFromPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)setSelection:(NSNumber *)line column:(NSNumber *)column {
  [self.oakTextView selectToLine:line andColumn:column];
}

- (void)copySelection {
  [self.oakTextView writeSelectionToPasteboard:[NSPasteboard generalPasteboard]
      types:[NSArray arrayWithObject:@"NSStringPboardType"]];
}

/* Returns the contents of the current selection. */
- (NSDictionary *)getSelectedText {
  // We're using pasteboards to copy data around. I'm not sure if there's a better approach.
  [self.oakTextView writeSelectionToPasteboard:self.textMateVimPasteboard
      types:[NSArray arrayWithObject:@"NSStringPboardType"]];
  NSString * selectedText = [self.textMateVimPasteboard stringForType:@"NSStringPboardType"];
  return [NSDictionary dictionaryWithObjectsAndKeys: selectedText, @"selectedText", nil];
}

- (NSDictionary *)hasSelection {
  NSNumber * hasSelection = [NSNumber numberWithBool:[self.oakTextView hasSelection]];
  return [NSDictionary dictionaryWithObjectsAndKeys: hasSelection, @"hasSelection", nil];
}

/* Scrolls the OakTextView to the given Y coordinate. TODO(philc): Support X as well. */
- (void)scrollTo:(NSNumber *)x y:(NSNumber *)y {
  NSPoint scrollPosition = [self getScrollPosition:(NSView *)self.oakTextView];
  scrollPosition.y = y.floatValue;
  [self.oakTextView scrollPoint:scrollPosition];
}

- (void)addNewline { [self.oakTextView insertText:@"\n"]; }

/* NOTE(philc): I'm not sure what the argument is supposed to be to the undo method, but using 0 causes the
 * last action to be undone, which is precisely what we need. */
- (void)undo { [self.oakTextView undo:0]; }

- (void)enterMode:(NSString *)mode {
  currentMode = mode;
  if (cursorView)
    [cursorView setMode:mode];
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

/*
 * Deselects any current selection. This is implemented on the objective C side because we don't want to
 * move the cursor unless there is a selection, and that can only be known after executing all of the commands
 * sent by the Ruby event handler.
 */
- (void)selectNone {
  if ([self.oakTextView hasSelection])
    [self.oakTextView performSelector: NSSelectorFromString(@"moveBackward:") withObject:self];
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

/*
 * Given a menu item title, simulates clicking on that menu item. This is useful for leveraging the standard
 * TextMate menu bar commands from TextMateVim commands.
 */
- (void)clickMenuItem:(NSString *)menuItemTitle {
  NSMenuItem * menuItem = [menuItemsByTitle objectForKey: menuItemTitle];

  NSLog(@"menu %@", menuItem.title);
  if (menuItem) {
    if (menuItem.isHiddenOrHasHiddenAncestor || !menuItem.isEnabled)
      return;
    NSLog(@"%@", @"performing selector...");
    // menuItem.target is nil, so this will cause the message to be sent through the responder chain.
    [menuItem.menu performActionForItemAtIndex:[menuItem.menu indexOfItemWithTitle:menuItem.title]];
    // [self performSelector:menuItem.action withObject:nil];
  } else {
    NSLog(@"In clickMenuItem, could not find a menu item corresponding to %@", menuItemTitle);
  }
}

/* For the given NSView, retrieves its scroll position. */
- (NSPoint)getScrollPosition:(NSView *)view { return view.enclosingScrollView.documentVisibleRect.origin; }

/* OakTextView is TextMate's text editor implementation. */
- (NSView *)oakTextView { return (NSView *)self.firstResponder; }

/* A scratch pasteboard used for copying the current editor's selection and serializing it to a string. */
- (NSPasteboard *)textMateVimPasteboard { return [NSPasteboard pasteboardWithName:@"textMateVimPasteboard"]; }

/*
 * The TabBarView which controls the tabs for the current window. nil if only a single file is being edited.
 * NOTE(philc): This will break if the structure of the view hierarchy has been changed by another plugin.
 * For instance, the TextMateMiniMap changes the view hiearchy. A more reliable appraoch may be to find the
 * menu item for "Navigation > Next File Tab" and invoke its action directly. See NSMenuItem.
 */
- (id)oakTabBarView {
  NSView * current = self.oakTextView;
  // Walk through OakTextView's parent views until we hit "NSThemeFrame". OakTabBarView is a child of
  // NSThemeFrame.
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

/* Returns a flattened list of the application's NSMenuItems. */
- (NSArray *)menuItemsList {
  NSMutableArray * menuItems = [NSMutableArray arrayWithCapacity:30];
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
      [menuItems addObject: menuItem];
    }
  }
  return menuItems;
}

/*
 * Returns a mapping from { "menu item title" => NSMenuItem }. Menu item titles are fully qualified where
 * each level of the hierarchy is separated by " > ", e.g. "File > Save".
 */
- (NSDictionary *)getMenuItemsByTitle:(NSArray *)menuItems {
  NSMutableDictionary * menuItemsByTitle = [NSMutableDictionary dictionaryWithCapacity: menuItems.count];
  for (int i = 0; i < menuItems.count; i++) {
    NSMenuItem * menuItem = [menuItems objectAtIndex:i];
    [menuItemsByTitle setObject:menuItem forKey:[self fullyQualifiedMenuItemTitle:menuItem]];
  }
  return menuItemsByTitle;
}

- (NSString *)fullyQualifiedMenuItemTitle:(NSMenuItem *)menuItem {
  NSMutableArray * title= [NSMutableArray arrayWithCapacity: 4];
  while (menuItem) {
    [title insertObject:menuItem.title atIndex:0];
    menuItem = menuItem.parentItem;
  }
  return [title componentsJoinedByString: @" > "];
}

/*
 * Given an array of shortcuts, iterates through all of the submenus in the app's menu bar and disables
 * shortcuts for those menu items which conflict. This is to ensure that TextMateVim's keybindings (in
 * particular CTRL+U) aren't swallowed by Textmate.
 * - shortcuts: an array of the form: [[key, modifier_flags], ...]
 */
- (void)removeMenuItemShortcutsWhichMatch:(NSArray *)shortcuts menuItems:(NSArray *)menuItems {
  for (int i = 0; i < menuItems.count; i++) {
    NSMenuItem * menuItem = [menuItems objectAtIndex:i];
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

@end
