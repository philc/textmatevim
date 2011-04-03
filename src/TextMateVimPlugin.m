#import "TextMateVimPlugin.h"
#import "TextMateVimWindow.h"
#import "JSON.h"

/*
 * This plugin substitutes its own class for NSWindow so that it can intercept keyboard events.
 * It forks off a Ruby coprocess which implements all of the modal keybinding logic.
 */
@implementation TextMateVimPlugin

@synthesize updater;

int MAX_JSON_MESSAGE_SIZE = 8096;

// Pipes to the Ruby event router process.
static FILE * eventRouterStdin;
static FILE * eventRouterStdout;

- (id)initWithPlugInController:(id <TMPlugInController>)controller {
  int pid = [TextMateVimPlugin startEventRouter];
  NSLog(@"TextMateVim has arrived. The ruby coprocess ID: %i", pid);

  [self checkForNewerVersions];

  // "poseAsClass" has been deprecated, but it still works. Use performSelector to avoid compiler
  // warnings and errors.
  [TextMateVimWindow performSelector: NSSelectorFromString(@"poseAsClass:") withObject: [NSWindow class]];
  return [super init];
}

- (void)checkForNewerVersions {
  // We're using the Sparkle update framework.
  updater = [SUUpdater updaterForBundle:[NSBundle bundleWithIdentifier:@"textmatevim"]];
  [updater resetUpdateCycle];
  // Start checking right now for an update. This shouldn't be necessary according to the Sparkle docs, but
  // I could never get the "automatic update scheduling" logic of Sparkle to trigger an actual update check.
  [updater checkForUpdatesInBackground];
}

/*
 * Spawns an event router coprocess.
 */
+ (int)startEventRouter {
  // Refer to this post on setting up bidrectional pipes.
  // http://www.cocoabuilder.com/archive/cocoa/1018-bi-directional-pipes-follow-up.html
  NSLog(@"startEventRouter");
  int readPipe[2], writePipe[2];
  if (pipe(readPipe) < 0 || pipe(writePipe) < 0)
    return -1;
  int pid;

  switch (pid = fork()) {
    case -1: break; // error

    case 0: // child
      close(readPipe[0]);
      close(writePipe[1]);

      // Map the read pipe and the write pipe to stdout and stdin of the process we're about to spawn.
      dup2(readPipe[1], 1); // parent reads from child's stdout.
      dup2(writePipe[0], 0); // parent writes to child's stdin.
    
      NSString * eventRouterFile = [[NSBundle bundleWithIdentifier:@"textmatevim"]
          pathForResource:@"event_handler" ofType:@"rb"];
      execl([eventRouterFile UTF8String], "", (char *)0);
    break;

    default: // parent
      close(readPipe[1]);
      close(writePipe[0]);
      eventRouterStdout = fdopen(readPipe[0], "r");
      eventRouterStdin = fdopen(writePipe[1], "w");
  }
  return pid;
}

/*
 * Sends a message to the Ruby event router process. The result will be a dictionary deserialized from JSON.
 */
+ (NSDictionary *)sendEventRouterMessage:(NSDictionary *)messageBody {
  fputs([[messageBody JSONRepresentation] UTF8String], eventRouterStdin);
  fputs("\n", eventRouterStdin);
  fflush(eventRouterStdin);

  char response[MAX_JSON_MESSAGE_SIZE];
  if (fgets(response, MAX_JSON_MESSAGE_SIZE, eventRouterStdout) == NULL) {
    NSLog(@"%Unable to read response from event_handler.rb!");
    return nil;
  } else {
    return [[NSString stringWithUTF8String: response] JSONValue];
  }
}

@end