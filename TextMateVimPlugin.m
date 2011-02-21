#import "TextMateVimPlugin.h"
#import "TextMateVimWindow.h"

@implementation TextMateVimPlugin

// Pipes to the event router process, written in Ruby.
static FILE * eventRouterStdin;
static FILE * eventRouterStdout;

- (id)initWithPlugInController:(id <TMPlugInController>)controller
{
  NSLog( @"TextMateVim has arrived." );
  int pid = [TextMateVimPlugin startEventRouter];
  NSLog(@"Ruby process ID: %i", pid);

  [TextMateVimWindow poseAsClass:[NSWindow class]];
  return [super init];
}

+ (FILE *)eventRouterStdin { return eventRouterStdin; }

+ (FILE *)eventRouterStdout { return eventRouterStdout; }

+ (int)startEventRouter {
  // Reference for this bidirectional pipe.
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
      NSLog(@"%@", @"Pipes assigned");
  }
  return pid;
}

@end
