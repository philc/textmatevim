/*
 * The view displays a block on top of the current window's cursor. It's used to render the cursor in Vim's
 * command mode and to help differentiate between modes.
 * The implementation and inspiration is largely taken from Kirt Fitzpatrick's ViMate.
 */

#import <Cocoa/Cocoa.h>

@interface CommandModeCursor : NSView {
  NSString * mode;
  NSColor * caretColor;
}

- (void)setMode:(NSString *)mode;
- (void)setCaretColor:(NSColor*)color;

@end
