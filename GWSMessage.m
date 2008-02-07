/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	January 2008
   
   This file is part of the WebMessages Library.

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

@implementation	GWSMessage

- (void) dealloc
{
  if (_document != nil)
    {
      GWSDocument        *m = _document;

      _document = nil;
      [m removeMessageNamed: _name];
      return;
    }
  [_name release];
  [_types release];
  [_elements release];
  [super dealloc];
}

- (NSString*) elementOfPartNamed: (NSString*)name
{
  return [_elements objectForKey: name];
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
      _name = [name copy];
      _document = document;
    }
  return self;
}

- (NSString*) name
{
  return _name;
}

- (NSArray*) partNames
{
  NSMutableArray        *m;
  NSEnumerator          *e;
  NSString              *n;

  m = [NSMutableArray arrayWithCapacity: [_types count] + [_elements count]];
  e = [_types keyEnumerator];
  while ((n = [e nextObject]) != nil)
    {
      [m addObject: n];
    }
  e = [_elements keyEnumerator];
  while ((n = [e nextObject]) != nil)
    {
      [m addObject: n];
    }
  [m sortUsingSelector: @selector(compare:)];
  return m;
}

- (void) setElement: (NSString*)type forPartNamed: (NSString*)name
{
  [_types removeObjectForKey: name];
  [_elements setObject: type forKey: name];
}

- (void) setType: (NSString*)type forPartNamed: (NSString*)name
{
  [_elements removeObjectForKey: name];
  [_types setObject: type forKey: name];
}

- (GWSElement*) tree
{
  GWSElement    *tree;

  tree = [[GWSElement alloc] initWithName: @"message"
                                namespace: nil
                                qualified: [_document qualify: @"message"]
                               attributes: nil];
  [tree setAttribute: _name forKey: @"name"];
  NSLog(@"FIXME .. message tree not implemented");
  return [tree autorelease];
}

- (NSString*) typeOfPartNamed: (NSString*)name
{
  return [_types objectForKey: name];
}

@end

