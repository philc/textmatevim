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

+ (BOOL)isValidWindowType:(NSWindow *)window {
  return [[window firstResponder] isKindOfClass:NSClassFromString(@"OakTextView")];
}

- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isValidWindowType:self] || [event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  // If we've just changed windows, make sure that our cursor is being rendered in the current window.
  if (self != currentWindow) {
    currentWindow = self;
    id responder = [self firstResponder];
    if (cursorView)
      [cursorView removeFromSuperview];
    cursorView = [[CommandModeCursor alloc] initWithFrame:[responder bounds]];
    [responder addSubview:cursorView];
    [cursorView setMode:@"command"];
  }

  // TODO(philc): When changing modes, update the cursor view.

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
      event.charactersIgnoringModifiers, @"characters",
      [NSNumber numberWithInt: event.modifierFlags], @"modifierFlags",
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
  if (commands.count > 0) {
    for (int i = 0; i < commands.count; i++)
      [[self firstResponder] performSelector: NSSelectorFromString([commands objectAtIndex:i])
          withObject: self];
  } else {
    [super sendEvent: event];
  }
}
@end
