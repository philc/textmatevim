//
//  NSColor_categories.m
//  ViMate
//
//  Created by Rodrigue Cloutier on 27/06/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "NSColor_categories.h"


@implementation NSColor (NSColor_categories)

/*
  NSColor: Instantiate from Web-like Hex RRGGBB string
  Original Source: <http://cocoa.karelia.com/Foundation_Categories/NSColor__Instantiat.m>
  (See copyright notice at <http://cocoa.karelia.com>)
*/

+ (NSColor *) colorFromHexRGB:(NSString *) inColorString
{
  NSColor *result = nil;
  unsigned int colorCode = 0;
  unsigned char redByte, greenByte, blueByte;

  if (nil != inColorString)
  {
    if( [inColorString hasPrefix:@"#"] ){
      inColorString = [inColorString substringFromIndex:1];
    }
    NSScanner *scanner = [NSScanner scannerWithString:inColorString];
    (void) [scanner scanHexInt:&colorCode];  // ignore error
  }
  redByte    = (unsigned char) (colorCode >> 16);
  greenByte  = (unsigned char) (colorCode >> 8);
  blueByte  = (unsigned char) (colorCode);  // masks off high bits
  result = [NSColor
    colorWithCalibratedRed:  (float)redByte  / 0xff
             green:  (float)greenByte/ 0xff
              blue:  (float)blueByte  / 0xff
             alpha:1.0];
  return result;
}

@end
