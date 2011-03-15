#import <Cocoa/Cocoa.h>

@interface TextMateVimWindow : NSWindow {
  // Note that you can't add instance variables when posing as another class (in this case, to NSWindow).
}

- (void)addNewline;
+ (BOOL)isEditorWindow:(NSWindow *)theWindow;
- (void)sendEvent:(NSEvent *)theEvent;
- (void)enterMode:(NSString *)mode;
- (NSPoint)getScrollPosition:(NSView *)view;
- (NSView *)oakTextView;
- (void)copySelection;
- (id)oakTabBarView;
- (void)removeMenuItemShortcutsWhichMatch:(NSArray *)keybindings;
- (void)nextTab;
- (void)previousTab;
- (NSDictionary *)handleMessage:(NSDictionary *)message;

@end
