/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	November 2008
   
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

@implementation	GWSExtensibility

- (NSString*) validate: (GWSElement*)node
		   for: (GWSDocument*)document
		    in: (id)section
		 setup: (GWSService*)service
{
  return nil;
}

@end

@implementation	GWSSOAPExtensibility
- (NSString*) validate: (GWSElement*)node
		   for: (GWSDocument*)document
		    in: (id)section
		 setup: (GWSService*)service
{
  NSString	*name = [node name];
  NSString	*pName = [[node parent] name];
  NSDictionary	*a = [node attributes];
  GWSSOAPCoder	*c;

  /* If we are setting up from a SOAP element, we must be doing a SOAP
   * message of some sort, so we can check to see that the service has
   * the correct type of coder.
   */
  c = (GWSSOAPCoder*)[service coder];
  if (service != nil && [c isKindOfClass: [GWSSOAPCoder class]] == NO)
    {
      c = [GWSSOAPCoder new];
      [service setCoder: c];
      [c release];
    }

  if ([section isKindOfClass: [GWSBinding class]])
    {
      // This is a binding element inside a document
      if ([name isEqualToString: @"binding"])
	{
	  NSString	*style;
	  NSString	*transport;

	  style = [a objectForKey: @"style"];
	  if (style == nil
	    || [style isEqualToString: @"document"])
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleDocument];
	    }
	  else if ([style isEqualToString: @"rpc"])
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleRPC];
	    }
	  else
	    {
	      return [NSString stringWithFormat:
		@"unknown style in binding: '%@'", style];
	    }

	  transport = [a objectForKey: @"transport"];
	  if (transport == nil || [transport isEqualToString:
	    @"http://schemas.xmlsoap.org/soap/http"])
	    {
	    }
	  else
	    {
	      return [NSString stringWithFormat:
		@"unsupported transport mechanism: '%@'", transport];
	    }
	}
      else if ([name isEqualToString: @"operation"])
	{
	  NSString	*style = [a objectForKey: @"style"];
	  NSString	*action = [a objectForKey: @"soapAction"];

	  /* A missing style defaults to 'document'
	   */
	  if (style == nil || [style isEqualToString: @"document"] == YES)
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleDocument];
	    }
	  else if ([style isEqualToString: @"rpc"])
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleRPC];
	    }
	  else
	    {
	      return [NSString stringWithFormat:
		@"bad SOAP style: '%@' in operation", style];
	    }

	  /* A missing action defaults to '""'
	   */
	  if (action == nil)
	    {
	      [service setSOAPAction: @"\"\""];
	    }
	  else
	    {
	      [service setSOAPAction: action];
	    }
	}
      else if ([pName isEqualToString: @"input"]
        ||[pName isEqualToString: @"output"])
	{
	  NSString		*use = [a objectForKey: @"use"];
	  NSString		*namespace = [a objectForKey: @"namespace"];
          NSMutableDictionary	*p = [service webServiceParameters];

	  if ([use isEqualToString: @"literal"] == NO
	    && [use isEqualToString: @"encoded"] == NO)
	    {
	      return [NSString stringWithFormat:
		@"bad SOAP 'use' value: '%@' in %@ %@", use, section, name];
	    }

	  if ([name isEqualToString: @"body"])
	    {
	      [p setObject: use forKey: GWSSOAPUseKey];
	      if (namespace != nil)
		{
	          [p setObject: namespace forKey: GWSSOAPNamespaceURIKey];
		}
	    }
	  else if ([name isEqualToString: @"header"])
	    {
	      id	h;

	      /* If we have a non-empty headers dictionary,
	       * we can set it up.  Otherwise we must assume that
	       * the coder's delegate is going to provide the headers.
	       */
	      h = [p objectForKey: GWSSOAPMessageHeadersKey];
	      if ([h isKindOfClass: [NSDictionary class]] == YES
		&& [h count] > 0)
		{
		  NSString	*part;
		  NSString	*messageName;

		  /* Ensure the header info can be modified.
		   */
		  if ([h isKindOfClass: [NSMutableDictionary class]] == NO)
		    {
		      h = [h mutableCopy];
		      [p setObject: h forKey: GWSSOAPMessageHeadersKey];
		      [h release];
		    }

	          [h setObject: use forKey: GWSSOAPUseKey];

		  /* Set the default namespace for the contents of Header
		   * if known.
		   */
		  if (namespace != nil)
		    {
		      [h setObject: namespace forKey: GWSSOAPNamespaceURIKey];
		    }

		  /* If there is no 'message' attribute,
		   * we must be using the message defined
		   * by the abstract portType for this operation.
		   */
		  part = [a objectForKey: @"part"];
		  messageName = [a objectForKey: @"message"];
		  if (part != nil && messageName == nil)
		    {
		      NSString		*name;
		      GWSElement	*elem;

		      /* This is in binding/operation/input/header, so the name
		       * of our parent's parent is the operation name.
		       */
		      name = [[[node parent] parent] name];
		      elem = [[(GWSBinding*)section type]
			operationWithName: name create: NO];
		      if (elem == nil)
			{
			  return [NSString stringWithFormat:
			    @"No operation '%@' found in binding", name];
			}
		      elem = [elem firstChild];
		      while (elem != nil
			&& [[elem name] isEqual: @"input"] == NO)
			{
			  elem = [elem sibling];
			}
		      if (elem != nil)
			{
			  messageName
			    = [[elem attributes] objectForKey: @"message"];
			}
		      if (messageName == nil)
			{
			  return [NSString stringWithFormat:
			    @"No message for '%@' found in binding", name];
			}
		    }
		  if (part && messageName)
		    {
		      GWSMessage	*message;

		      message = [document messageWithName: messageName
						   create: NO];
		      if (message == nil)
			{
			  return [NSString stringWithFormat:
			    @"Unable to find message '%@'", messageName];
			}
		      else
			{
			  NSString	*pName;

			  pName = [message elementOfPartNamed: part];
			  if (pName == nil)
			    {
			      return [NSString stringWithFormat:
				@"Unable to find part '%@' in message '%@'",
				part, messageName];
			    }
			}
		    }

		}
	    }
	  else
	    {
	      return [NSString stringWithFormat:
		@"unknown SOAP extensibility: '%@' in %@", name, section];
	    }
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in binding", name];
	}
    }
  else if ([section isKindOfClass: [GWSPort class]] == YES)
    {
      /* This is a port element inside a service element inside a document
       */
      if ([name isEqualToString: @"address"])
	{
	  NSString	*location;

	  location = [[node attributes] objectForKey: @"location"];
	  if (location == nil)
	    {
	      return @"missing location in port address";
	    }
	  else
	    {
	      NSURL	*u = [NSURL URLWithString: location];

	      if (u == nil)
		{
		  return [NSString stringWithFormat:
		    @"bad location '%@' in SOAP port address: '%@'", location];
		}
	      [service setURL: location];
	    }
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in port", name];
	}
    }
  return nil;
}

@end
