#import <Cocoa/Cocoa.h>

@protocol TMPlugInController
- (float)version;
@end

@interface TextMateVimPlugin : NSObject {
}
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
+ (FILE *)eventRouterStdin;
+ (FILE *)eventRouterStdout;
+ (int)startEventRouter;
@end
