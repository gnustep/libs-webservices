/** 
   Copyright (C) 2009 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2009
   
   This file is part of the WebServices package.

   This is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Date: 2007-09-14 13:54:55 +0100 (Fri, 14 Sep 2007) $ $Revision: 25485 $
   */ 

#import	<Foundation/Foundation.h>
#import	"GWSPrivate.h"

int
main()
{
  NSAutoreleasePool     *pool;
  NSUserDefaults	*defs;
  GWSCoder              *coder;
  NSData                *xml;
  NSString              *file;
  NSMutableDictionary   *result;

  pool = [NSAutoreleasePool new];

  defs = [NSUserDefaults standardUserDefaults];

  file = [defs stringForKey: @"File"];
  if (file == nil)
    {
      GSPrintf(stderr, @"Usage ... testGWSSOAPCoder -File filename\n");
      GSPrintf(stderr, @"	-Record filename (to store results)\n");
      GSPrintf(stderr, @"	-Compare filename (to check results)\n");
      return 1;
    }
  xml = [NSData dataWithContentsOfFile: file];
  if (xml == nil)
    {
      GSPrintf(stderr, @"Unable to load XML from file '%@'\n", file);
      return 1;
    }

  coder = [GWSSOAPCoder new];
  [coder setDebug: [defs boolForKey: @"Debug"]];

  result = [coder parseMessage: xml];
  if (result == nil)
    {
      GSPrintf(stderr, @"Failed to decode data from file '%@'\n", file);
      return 1;
    }
  
  file = [defs objectForKey: @"Record"];
  if (file != nil)
    {
      if (NO == [result writeToFile: file atomically: NO])
	{
          GSPrintf(stderr, @"Failed to record result to file '%@'\n", file);
          return 1;
	}
    }

  file = [defs objectForKey: @"Compare"];
  if (file == nil)
    {
      GSPrintf(stdout, @"%@", result);
    }
  else
    {
      NSDictionary	*old;

      old = [NSDictionary dictionaryWithContentsOfFile: file];
      if (old == nil)
	{
          GSPrintf(stderr, @"Failed to load dictionary from file '%@'\n", file);
          return 1;
	}
      if ([old isEqual: result] == NO)
	{
          GSPrintf(stderr, @"Decode result does not match file '%@'\n", file);
          return 1;
	}
    }

  [pool release];
  return 0;
}

