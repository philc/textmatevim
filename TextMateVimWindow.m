/*
 * We're using this JSON framework: http://stig.github.com/json-framework/
 */
#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import "CommandModeCursor.h"
#import <JSON/JSON.h>

@implementation TextMateVimWindow

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
  if (currentWindow != nil) {
    [[currentWindow firstResponder] unbind:@"lineNumber"];
    [[currentWindow firstResponder] unbind:@"columnNumber"];
  }

  currentWindow = self;
  currentMode = currentMode ? currentMode : @"insert";
  id responder = [self firstResponder];

  if (cursorView)
    [cursorView removeFromSuperview];
  cursorView = [[CommandModeCursor alloc] initWithFrame:[responder bounds]];
  [responder addSubview:cursorView];
  [cursorView setMode:currentMode];

  // NOTE(philc): For some reason these values are only available via binding. There are no methods on
  // OakTextView for lineNumber and columnNumber.
  [responder bind:@"lineNumber" toObject:self withKeyPath:@"lineNumber" options:nil];
  [responder bind:@"columnNumber" toObject:self withKeyPath:@"columnNumber" options:nil];
}

- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isValidWindowType:self] || [event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  // If we've just changed windows, make sure that our cursor is being rendered in the current window.
  if (self != currentWindow)
    [self setFocusedWindow:self];

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
      event.charactersIgnoringModifiers, @"characters",
      [NSNumber numberWithInt: event.modifierFlags], @"modifierFlags",
      lineNumber, @"lineNumber",
      columnNumber, @"columnNumber",
      [NSNumber numberWithBool:[[self firstResponder] hasSelection]], @"hasSelection",
      nil];
  fputs([[dict JSONRepresentation] UTF8String], [TextMateVimPlugin eventRouterStdin]);
  fputs("\n", [TextMateVimPlugin eventRouterStdin]);
  fflush([TextMateVimPlugin eventRouterStdin]);

  char response[1024];
  if (fgets(response, 1024, [TextMateVimPlugin eventRouterStdout]) == NULL) {
    NSLog(@"%Unable to read response from event_handler.rb!");
    [super sendEvent: event];
    return;
  }

  NSArray * commands = [[NSString stringWithUTF8String: response] JSONValue];
  NSArray * nonTextViewCommands = [NSArray arrayWithObjects:
      @"enterCommandMode", @"enterInsertMode", @"addNewline", @"writeSelectionToPasteboard", @"noOp",
      @"setSelection:column:", @"undo", nil];

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
        [[self firstResponder] performSelector: NSSelectorFromString(command) withObject: self];
    }
  } else {
    [super sendEvent: event];
  }
}

/*
 * These are commands that the Ruby event handler can invoke.
 */
- (void)noOp { }

- (void)setSelection:(NSNumber *)line column:(NSNumber *)column {
  [[self firstResponder] selectToLine:line andColumn:column];
}

- (void)addNewline { [[self firstResponder] insertText:@"\n"]; }

/* NOTE(philc): I'm not sure what this argument is supposed to be to undo, but using 0 causes the last
 * action to be undone, which is precisely what we need. */
- (void)undo { [[self firstResponder] undo:0]; }

- (void)enterCommandMode {
  currentMode = @"command";
  if (cursorView)
    [cursorView setMode:currentMode];
}

- (void)enterInsertMode {
  currentMode = @"insert";
  if (cursorView)
    [cursorView setMode:currentMode];
}

- (void)writeSelectionToPasteboard {
  [[self firstResponder] writeSelectionToPasteboard:[NSPasteboard generalPasteboard]
      types:[NSArray arrayWithObject:@"NSStringPboardType"]];
}

- (void)setLineNumber:(id)theLineNumber {
  if (lineNumber)
    [lineNumber release];
  lineNumber = theLineNumber;
  [lineNumber retain];
}

- (NSNumber *)lineNumber { return lineNumber; }

- (void)setColumnNumber:(id)theColumnNumber {
  if (columnNumber)
    [columnNumber release];
  columnNumber = theColumnNumber;
  [columnNumber retain];
}

- (NSNumber *)columnNumber { return columnNumber; }

@end