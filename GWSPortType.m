/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	January 2008
   
   This file is part of the WebPortTypes Library.

   This library is free software; you can redistribute it and/or
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

   $Date: 2007-09-24 14:19:12 +0100 (Mon, 24 Sep 2007) $ $Revision: 25500 $
   */ 

#include <Foundation/Foundation.h>
#include "GWSPrivate.h"

@implementation	GWSPortType

- (void) dealloc
{
  if (_document != nil)
    {
      GWSDocument        *m = _document;

      _document = nil;
      [m removePortTypeNamed: _name];
      return;
    }
  [_operations release];
  [_name release];
  [super dealloc];
}

- (id) init
{
  [self release];
  return nil;
}

- (id) initWithName: (NSString*)name document: (GWSDocument*)document
{
  if ((self = [super init]) != nil)
    {
      GWSElement        *elem;

      _operations = [NSMutableDictionary new];
      _name = [name copy];
      _document = document;
      elem = [_document initializing];
      elem = [elem firstChild];
      while (elem != nil)
        {
          if ([[elem name] isEqualToString: @"operation"] == YES)
            {
              NSString          *name;

              name = [[elem attributes] objectForKey: @"name"];
              if (name == nil)
                {
                  NSLog(@"Operation without a name in WSDL!");
                }
              else
                {
                  [_operations setObject: elem forKey: name];
                }
            }
          else
            {
              NSLog(@"Bad element '%@' in portType", [elem name]);
            }
          elem = [elem sibling];
        }
    }
  return self;
}

- (NSString*) name
{
  return _name;
}

- (GWSElement*) tree
{
  GWSElement    *tree;
  GWSElement    *elem;
  NSEnumerator  *enumerator;

  tree = [[GWSElement alloc] initWithName: @"portType"
                                namespace: nil
                                qualified: [_document qualify: @"portType"]
                               attributes: nil];
  [tree setAttribute: _name forKey: @"name"];
  enumerator = [_operations objectEnumerator];
  while ((elem = [enumerator nextObject]) != nil)
    {
      elem = [elem mutableCopy];
      [tree addChild: elem];
      [elem release];
    }
  return [tree autorelease];
}
@end

