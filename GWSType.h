/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	January 2008
   
   This file is part of the WebServices Library.

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

   $Date: 2007-09-14 13:54:55 +0100 (Fri, 14 Sep 2007) $ $Revision: 25485 $
   */ 

#ifndef	INCLUDED_GWSTYPE_H
#define	INCLUDED_GWSTYPE_H

#import <Foundation/NSObject.h>

#if     defined(__cplusplus)
extern "C" {
#endif

@class  NSMutableDictionary;
@class  NSString;
@class  GWSDocument;
@class  GWSElement;

/**
 * Describes a data type, allowing it to be encoded more intelligently.
 */
@interface      GWSType : NSObject
{
@private
  NSString              *_name;
  GWSDocument           *_document;
  NSString              *_nameSpace;
  NSMutableDictionary   *_properties;
}

/** Returns the name of the type represented by the receiver.
 */
- (NSString*) name;

/** Returns the nameSpace of the type represented by the receiver.
 * This is an empty string if the receiver represents a type in the
 * global namespace.
 */
- (NSString*) nameSpace;

/** Returns the property set for the specified key or nil if none is set.
 */
- (id) propertyForKey: (NSString*)key;

/** Sets the property for the specified key.  The property may be nil to
 * remove an existing mapping.
 */
- (void) setProperty: (id)property forKey: (NSString*)key;

/** Return a tree representation of the receiver for output as part of
 * a WSDL document.
 */
- (GWSElement*) tree;
@end

#if	defined(__cplusplus)
}
#endif

#endif

