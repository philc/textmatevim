#import <Cocoa/Cocoa.h>

@interface TextMateVimWindow : NSWindow {
}

+ (BOOL)isValidWindowType:(NSWindow *)theWindow;
/*- (int)startEventRouter;*/
- (void)sendEvent:(NSEvent *)theEvent;


@end
