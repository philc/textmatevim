#import <Cocoa/Cocoa.h>

@interface TextMateVimWindow : NSWindow {
  // Note that you can't add instance variables when posing as another class (in this case, to NSWindow).
}

- (void)addNewline;
+ (BOOL)isValidWindowType:(NSWindow *)theWindow;
- (void)sendEvent:(NSEvent *)theEvent;
- (void)enterMode;
- (NSPoint)getScrollPosition:(NSView *)view;


@end
