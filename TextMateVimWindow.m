/*
 * We're using this JSON framework: http://stig.github.com/json-framework/
 */
#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import <JSON/JSON.h>

@implementation TextMateVimWindow

+ (BOOL)isValidWindowType:(NSWindow *)window {
  return [[window firstResponder] isKindOfClass:NSClassFromString(@"OakTextView")];
}

- (void)sendEvent:(NSEvent *)event {
  if (![TextMateVimWindow isValidWindowType:self] || [event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

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

- (void)go {
  NSLog(@"%@", @"executing go method!");
}

@end
