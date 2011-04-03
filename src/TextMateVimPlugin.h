#import <Cocoa/Cocoa.h>
#import <Sparkle/SUUpdater.h>

@protocol TMPlugInController
- (float)version;
@end

@interface TextMateVimPlugin : NSObject {
  @private SUUpdater * updater;
}

- (id)initWithPlugInController:(id <TMPlugInController>)aController;
- (void)checkForNewerVersions;
+ (int)startEventRouter;
+ (NSDictionary *)sendEventRouterMessage:(NSDictionary *)messageBody;

@property(retain) SUUpdater * updater;

@end
