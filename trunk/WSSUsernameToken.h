/** 
   Copyright (C) 2009 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	February 2009
   
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

#ifndef	INCLUDED_WSSUSERNAMETOKEN_H
#define	INCLUDED_WSSUSERNAMETOKEN_H

#import <Foundation/NSObject.h>
#import <Foundation/NSData.h>

#if     defined(__cplusplus)
extern "C" {
#endif

@class  NSDate;
@class  NSString;
@class  GWSElement;

/** <p>Supports the Web Services Security Username Token capability.<br />
 * The initial implementation only supports plaintext password client use
 * </p>
 * <p>Basic usage is simple, you create an instance of this class,
 * initialising it with the username and password to be used to authenticate
 * requests.  Then for each request you add the token to the request
 * header.  This can be done either as a delegate of a coder or the delegate
 * of a service.  The following shows the delegate method for a service:
 * </p>
 * <example>
 * - (GWSElement*) webService: (GWSService*)service willEncode: (GWSElement*)e
 * {
 *   if (e == nil || [[e name] isEqual: @"Header"] == YES)
 *     {
 *       e = [wsstoken addToHeader: e];	// May return new object.
 *     }
 *   return e;
 * }
 * </example>
 */
@interface	WSSUsernameToken : NSObject
{
@private
  NSString              *_name;
  NSString		*_password;
  NSDate		*_created;
  NSData		*_nonce;
  unsigned		_ttl;
}

/** Adds a representation of the receiver to the specified SOAP header
 * and returns the modified header.  If the header is nil, this simply
 * returns a representation of the receiver which can then be added to
 * a SOAP header.
 */
- (GWSElement*) addToHeader: (GWSElement*)header;

/** Initialise the receiver with a name and password used to authenticate
 * with a remote server.
 */
- (id) initWithName: (NSString*)name
	   password: (NSString*)password;

/** <init />
 * Initialise the receiver with a name and password used to authenticate
 * with a remote server.<br />
 * If ttl is non-zero, then a hash of the token is used along with a
 * creation date and nonce.  The actual ttl value is only of use for 
 * server-side code, which will reject any message whose creation date
 * is older than the number of seconds specified as the time to live.
 */
- (id) initWithName: (NSString*)name
	   password: (NSString*)password
	 timeToLive: (unsigned)ttl;

/** Return a tree representation of the WSS Username Token for inclusion
 * in the header of a SOAP request.
 */
- (GWSElement*) tree;
@end

/** Produce an SHA1 digest of an NSData object.<br />
 * Used internally by [WSSUsernameToken] when hash based authentication
 * is in use.
 */
@interface	NSData (SHA1)
/** This method produces an SHA1 digest of the receiver and returns the
 * resulting value as an autoreleased NSData object.
 */
- (NSData*) SHA1;
@end

#if	defined(__cplusplus)
}
#endif

#endif

