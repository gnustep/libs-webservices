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
  if ([section isEqualToString: @"binding"])
    {
      // This is a binding element inside a document
      if ([[node name] isEqualToString: @"binding"])
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
		@"unsupported coding style: '%@'", style];
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
	    @"unknown SOAP extensibility: '%@' in binding", [node name]];
	}
    }
  else if ([section isEqualToString: @"operation"])
    {
      /* This is an operation element inside a portType element
       */
      if ([[node name] isEqualToString: @"operation"])
	{
	  if ([[node attributes] objectForKey: @"SOAPAction"] == nil)
	    {
	      return @"missing SOAPAction in operation";
	    }
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in operation", [node name]];
	}
    }
  else if ([section isEqualToString: @"port"])
    {
      /* This is a port element inside a service element inside a document
       */
      if ([[node name] isEqualToString: @"address"])
	{
	  NSString	*location;
	  NSURL		*u;

	  location = [[node attributes] objectForKey: @"location"];
	  u = [NSURL URLWithString: location];
	  if (u == nil)
	    {
	      return [NSString stringWithFormat:
	        @"bad/missing location '%@' in SOAP port address: '%@'",
		location];
	    }
	}
      else
	{
	  return [NSString stringWithFormat:
	    @"unknown SOAP extensibility: '%@' in port", [node name]];
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

  /* Now we do section specific setup.
   */
  if ([section isEqualToString: @"binding"])
    {
      /* Binding setup 
       */
      if ([[node name] isEqualToString: @"binding"])
	{
	  NSDictionary	*a = [node attributes];
	  NSString	*style;
	  NSString	*transport;

	  style = [a objectForKey: @"style"];
	  if (style == nil || [style isEqualToString: @"document"])
	    {
	      [c setOperationStyle: GWSSOAPBodyEncodingStyleDocument];
	    }
	  else if ([style isEqualToString: @"rpc"])
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
  else if ([section isEqualToString: @"operation"])
    {
      /* This is an operation element inside a portType element
       */
      if ([[node name] isEqualToString: @"operation"])
	{
	  [service setSOAPAction: [[node attributes]
	    objectForKey: @"SOAPAction"]];
	}
    }
  else if ([section isEqualToString: @"port"])
    {
      /* This is a port element inside a service element
       */
      if ([[node name] isEqualToString: @"address"])
	{
	  [service setURL: [[node attributes] objectForKey: @"location"]];
	}
    }
  return nil;
}

@end
