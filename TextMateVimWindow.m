/*
 * Using the JSON framework: http://stig.github.com/json-framework/
 */

#import "TextMateVimWindow.h"
#import "TextMateVimPlugin.h"
#import <JSON/JSON.h>

@implementation TextMateVimWindow

+ (BOOL)isValidWindowType:(NSWindow *)window {
  return [[window firstResponder] isKindOfClass:NSClassFromString(@"OakTextView")];
}

- (void)sendEvent:(NSEvent *)event {
  if ([event type] != NSKeyDown) {
    [super sendEvent:event];
    return;
  }

  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
      event.charactersIgnoringModifiers, @"charactersIgnoringModifiers",
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

  NSDictionary *commandStack = [[NSString stringWithUTF8String: response] JSONValue];
  NSString * method = [commandStack objectForKey: @"method"];
  NSLog(@"%@", method);
  [self performSelector: NSSelectorFromString(method)];

  [super sendEvent: event];
}

- (void)go {
  NSLog(@"%@", @"executing go method!");
}

@end
