#import "CommandModeCursor.h"
#import "NSColor_categories.h"

@implementation CommandModeCursor

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self)
    [self setCaretColor: [[NSColor grayColor] colorWithAlphaComponent:0.5]];
  return self;
}

- (void)dealloc {
  [caretColor release];
  [super dealloc];
}

- (BOOL)isFlipped { return TRUE; }

- (void)setCaretColor:(NSColor*)color {
  [caretColor release];
  caretColor = color;
  [caretColor retain];
}

- (void)setMode:(NSString *)theMode {
  if ([theMode isEqualToString: mode])
    return;
  NSLog(@"%@", @"setting mode on command mode cursor");

  mode = theMode;
  [self setNeedsDisplay:TRUE];

  id oakTextView = [self superview];
  NSDictionary * stylesForCaret = [oakTextView stylesForCaret];
  NSColor * newColor = [NSColor colorFromHexRGB:[stylesForCaret valueForKey:@"foreground"]]; // or "selection"
  [self setCaretColor:[newColor colorWithAlphaComponent:0.6]];
}

- (void)drawRect:(NSRect)rect {
  if (![mode isEqualToString:@"command"])
    return;

  id oakTextView = [self superview];

  // Don't bother rendering our cursor when there's a selection being rendered.
  if ([oakTextView hasSelection])
    return;

  NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:
      [self methodSignatureForSelector:@selector(bounds)]];

  [invocation setSelector:@selector(caretRefreshRectangle)];
  [invocation invokeWithTarget:oakTextView];

  NSRect caretRect;
  [invocation getReturnValue:&caretRect];

  // TODO: this should be the width of a single character in the current font. Approximating for now.
  caretRect.size.width = 6;
  NSBezierPath * path = [NSBezierPath bezierPathWithRect:caretRect];

  [caretColor set];
  [path fill];
}

@end