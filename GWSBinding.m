/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	January 2008
   
   This file is part of the WebBindings Library.

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

@implementation	GWSBinding

- (void) dealloc
{
  if (_document != nil)
    {
      GWSDocument        *m = _document;

      _document = nil;
      [m removeBindingNamed: _name];
      return;
    }
  [_name release];
  [_type release];
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
      _name = [name copy];
      _document = document;
    }
  return self;
}

- (NSString*) name
{
  return _name;
}

- (void) setTypeName: (NSString*)type
{
  if (type != _type)
    {
      NSString  *old = _type;

      _type = [type retain];
      [old release];
    }
}

- (GWSElement*) tree
{
  GWSElement    *tree;

  tree = [[GWSElement alloc] initWithName: @"binding"
                                namespace: nil
                                qualified: [_document qualify: @"binding"]
                               attributes: nil];
  [tree setAttribute: _name forKey: @"name"];
  NSLog(@"FIXME .. binding tree not implemented");
  return [tree autorelease];
}

- (GWSPortType*) type
{
  if (_type != nil)
    {
      return [_document portTypeWithName: _type create: NO];
    }
  return nil;
}

@end

