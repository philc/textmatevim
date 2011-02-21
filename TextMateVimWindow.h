#import <Cocoa/Cocoa.h>

@interface TextMateVimWindow : NSWindow {
}

+ (BOOL)isValidWindowType:(NSWindow *)theWindow;
- (void)sendEvent:(NSEvent *)theEvent;
- (void)enterCommandMode;
- (void)enterInsertMode;


@end
