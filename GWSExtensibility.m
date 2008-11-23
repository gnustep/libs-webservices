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
		    in: (NSString*)section
{
  return nil;
}

- (NSString*) setupService: (GWSService*)service
		      from: (GWSElement*)node
		       for: (GWSDocument*)document
			in: (NSString*)section
{
  return nil;
}

@end

@implementation	GWSSOAPExtensibility
- (NSString*) validate: (GWSElement*)node
		   for: (GWSDocument*)document
		    in: (NSString*)section
{
  NSString	*name = [node name];

  if ([section isEqualToString: @"binding"])
    {
      // This is a binding element inside a document
      if ([name isEqualToString: @"binding"])
	{
	  NSDictionary	*a = [node attributes];
	  NSString	*style;
	  NSString	*transport;

	  style = [a objectForKey: @"style"];
	  if (style == nil
	    || [style isEqualToString: @"document"]
	    || [style isEqualToString: @"rpc"])
	    {
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
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in binding", name];
	}
    }
  else if ([section isEqualToString: @"input"]
    || [section isEqualToString: @"output"])
    {
      NSDictionary	*a = [node attributes];
      NSString		*use = [a objectForKey: @"use"];

      if ([name isEqualToString: @"body"])
	{
	}
      else if ([name isEqualToString: @"header"])
	{
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in %@", name, section];
	}
      if ([use isEqualToString: @"literal"])
	{
	}
      else if ([use isEqualToString: @"encoded"])
	{
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"bad SOAP 'use' value: '%@' in %@ %@", use, section, name];
	}
    }
  else if ([section isEqualToString: @"operation"])
    {
      /* This is an operation element inside a portType element
       */
      if ([name isEqualToString: @"operation"])
	{
	  NSString	*style;

	  /* No mandatory attributes.
	   */
	  style = [[node attributes] objectForKey: @"style"];
	  if (style != nil 
	    && [style isEqualToString: @"document"] == NO
	    && [style isEqualToString: @"rpc"] == NO)
	    {
	      return [NSString stringWithFormat:
		@"bad SOAP style: '%@' in operation", style];
	    }
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in operation", name];
	}
    }
  else if ([section isEqualToString: @"port"])
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

- (NSString*) setupService: (GWSService*)service
		      from: (GWSElement*)node
		       for: (GWSDocument*)document
			in: (NSString*)section
{
  NSString	*problem;
  NSString	*name;
  GWSSOAPCoder	*c;

  /* To avoid checking things in two places, we do all the checking in the
   * validation method, and call that method from here so that we know we
   * have good data to set up the service.
   **/
  problem = [self validate: node for: document in: section];
  if (problem != nil)
    {
      return problem;
    }

  /* If we are setting up from a SOAP element, we must be doing a SOAP
   * message of some sort, so we can check to see that the service has
   * the correct type of coder.
   */
  c = (GWSSOAPCoder*)[service coder];
  if ([c isKindOfClass: [GWSSOAPCoder class]] == NO)
    {
      c = [GWSSOAPCoder new];
      [service setCoder: c];
      [c release];
    }

  name = [node name];

  /* Now we do section specific setup.
   */
  if ([section isEqualToString: @"binding"])
    {
      /* Binding setup 
       */
      if ([name isEqualToString: @"binding"])
	{
	  NSDictionary	*a = [node attributes];
	  NSString	*style;
	  NSString	*transport;

	  style = [a objectForKey: @"style"];
	  if (style == nil || [style isEqualToString: @"document"])
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleDocument];
	    }
	  else
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleRPC];
	    }

	  transport = [a objectForKey: @"transport"];
	  if (transport == nil || [transport isEqualToString:
	    @"http://schemas.xmlsoap.org/soap/http"])
	    {
	    }
	}
    }
  else if ([section isEqualToString: @"input"]
    || [section isEqualToString: @"output"])
    {
      NSDictionary	*a = [node attributes];
      NSString		*use = [a objectForKey: @"use"];

      if ([name isEqualToString: @"body"])
	{
	}
      else if ([name isEqualToString: @"header"])
	{
	}

      if ([use isEqualToString: @"literal"])
	{
	  [c setUseLiteral: YES];
	}
      else
	{
	  [c setUseLiteral: NO];
	}
    }
  else if ([section isEqualToString: @"operation"])
    {
      /* This is an operation element inside a portType element
       */
      if ([name isEqualToString: @"operation"])
	{
	  NSDictionary	*attributes = [node attributes];
	  NSString	*style = [attributes objectForKey: @"style"];
	  NSString	*action = [attributes objectForKey: @"soapAction"];

	  /* If present, the style overrides the one from the binding.
	   */
	  if (style != nil)
	    {
	      if ([style isEqualToString: @"rpc"])
		{
		  [c setOperationStyle: GWSSOAPBodyEncodingStyleRPC];
		}
	      else
		{
		  [c setOperationStyle: GWSSOAPBodyEncodingStyleDocument];
		}
	    }

	  /* The SOAP action is optional.
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
    }
  else if ([section isEqualToString: @"port"])
    {
      /* This is a port element inside a service element
       */
      if ([name isEqualToString: @"address"])
	{
	  [service setURL: [[node attributes] objectForKey: @"location"]];
	}
    }
  return nil;
}

@end
