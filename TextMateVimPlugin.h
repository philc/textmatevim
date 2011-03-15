#import <Cocoa/Cocoa.h>

@protocol TMPlugInController
- (float)version;
@end

@interface TextMateVimPlugin : NSObject {
}
- (id)initWithPlugInController:(id <TMPlugInController>)aController;
+ (int)startEventRouter;
+ (NSDictionary *)sendEventRouterMessage:(NSDictionary *)messageBody;
@end
