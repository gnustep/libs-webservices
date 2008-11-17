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

   $Date: 2007-09-24 14:19:12 +0100 (Mon, 24 Sep 2007) $ $Revision: 25500 $
   */ 

#import <Foundation/NSArray.h>
#import	<Foundation/NSDictionary.h>
#import	<Foundation/NSFileHandle.h>
#import	<Foundation/NSMapTable.h>
#import	<Foundation/NSNotification.h>
#import	<Foundation/NSObject.h>
#import	<Foundation/NSSet.h>
#import	<Foundation/NSString.h>
#import	<Foundation/NSTimer.h>

#import "GWSBinding.h"
#import "GWSCoder.h"
#import "GWSConstants.h"
#import "GWSElement.h"
#import "GWSExtensibility.h"
#import "GWSDocument.h"
#import "GWSMessage.h"
#import "GWSPort.h"
#import "GWSPortType.h"
#import "GWSService.h"
#import "GWSType.h"


@interface      GWSBinding (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end
@interface      GWSDocument (Private)
- (NSString*) _setupService: (GWSService*)service
		       from: (GWSElement*)element
		         in: (NSString*)section;
- (NSString*) _validate: (GWSElement*)element in: (NSString*)section;
@end
@interface      GWSMessage (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end
@interface      GWSPort (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end
@interface      GWSPortType (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end
@interface      GWSService (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end
@interface      GWSType (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document;
- (void) _remove;
@end

