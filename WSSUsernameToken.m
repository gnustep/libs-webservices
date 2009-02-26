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

   $Date: 2007-09-24 14:19:12 +0100 (Mon, 24 Sep 2007) $ $Revision: 25500 $
   */ 

#import <Foundation/Foundation.h>
#import "GWSPrivate.h"
#import "WSSUsernameToken.h"

@implementation	WSSUsernameToken

- (GWSElement*) addToHeader: (GWSElement*)header
{
  GWSElement	*security;
  GWSElement	*token;
  GWSElement	*elem;
  NSString	*prefix;
  NSString	*ns;
  NSString	*tName;
  NSString	*uName;
  NSString	*pName;

  ns = @"http://docs.oasis-open.org/wss/2004/01/"
    @"oasis-200401-wss-wssecurity-secext-1.0.xsd";

  /* Try to find any existing WSS Security element in the header.
   */
  security = [header firstChild];
  while (security != nil)
    {
      if ([[security name] isEqualToString: @"Security"] == YES
	&& [[security namespace] isEqualToString: ns] == YES)
	{
	  break;
	}
      security = [security sibling];
    }

  /* Create a new security element if we didn't find one.
   */
  if (security == nil)
    {
      NSString	*qName;

      prefix = [header prefixForNamespace: ns];
      if (prefix == nil)
	{
	  qName = @"wsse:Security";
	}
      else if ([prefix length] == 0)
	{
	  qName = @"Security";
	}
      else
	{
	  qName = [prefix stringByAppendingString: @":Security"];
	}
      security = [[GWSElement alloc] initWithName: @"Security"
					namespace: ns
					qualified: qName
				       attributes: nil];
      if (prefix == nil)
	{
	  /* There is no prefix for our namespace, so we will used
	   * our default one ... 'wsse'.
	   */
	  prefix = @"wsse";

	  /* We need to set up the prefix to namespace mapping, and we
	   * prefer to do that in the top level (SOAP Envelope) if
	   * possible.
	   */
	  if ([[[header parent] name] isEqualToString: @"Envelope"])
	    {
              [[header parent] setNamespace: ns forPrefix: @"wsse"];
	    }
	  else
	    {
              [security setNamespace: ns forPrefix: @"wsse"];
	    }
	}
      if (header == nil)
	{
          header = security;
          [security autorelease];
	}
      else
	{
	  [header addChild: security];
	  [security release];
	}
    }
    
  prefix = [security prefix];
  if ([prefix isEqualToString: @"wsse"] == YES)
    {
      tName = @"wsse:UsernameToken";
      uName = @"wsse:Username";
      pName = @"wsse:Password";
    }
  else
    {
      tName = @"UsernameToken";
      uName = @"Username";
      pName = @"Password";
      if ([prefix length] > 0)
	{
	  tName = [NSString stringWithFormat: @"%@:%@", prefix, tName];
	  uName = [NSString stringWithFormat: @"%@:%@", prefix, uName];
	  pName = [NSString stringWithFormat: @"%@:%@", prefix, pName];
	}
    }

  token = [[GWSElement alloc] initWithName: @"UsernameToken"
				 namespace: ns
				 qualified: tName
				attributes: nil];
  [security addChild: token];
  [token release];

  elem = [[GWSElement alloc] initWithName: @"Username"
				namespace: ns
				qualified: uName
			       attributes: nil];
  [token addChild: elem];
  [elem release];
  [elem addContent: _name];

  elem = [[GWSElement alloc] initWithName: @"Password"
				namespace: ns
				qualified: pName
			       attributes: nil];
  [token addChild: elem];
  [elem release];
  [elem addContent: _password];

  return header;
}

- (void) dealloc
{
  [_name release];
  [_password release];
  [super dealloc];
}

- (id) init
{
  [self release];
  return nil;
}

- (id) initWithName: (NSString*)name password: (NSString*)password
{
  _name = [name copy];
  _password = [password copy];
  return self;
}

- (GWSElement*) tree
{
  return [self addToHeader: nil];
}
@end

