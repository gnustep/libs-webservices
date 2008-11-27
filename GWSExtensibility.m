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
{
  return nil;
}

- (NSString*) setupService: (GWSService*)service
		      from: (GWSElement*)node
		       for: (GWSDocument*)document
		        in: (id)section
{
  return nil;
}

@end

@implementation	GWSSOAPExtensibility
- (NSString*) validate: (GWSElement*)node
		   for: (GWSDocument*)document
		    in: (id)section
{
  NSString	*name = [node name];
  NSString	*pName = [[node parent] name];
  NSDictionary	*a = [node attributes];

  if ([section isKindOfClass: [GWSBinding class]])
    {
      // This is a binding element inside a document
      if ([name isEqualToString: @"binding"])
	{
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
      else if ([name isEqualToString: @"operation"])
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
      else if ([pName isEqualToString: @"input"]
        ||[pName isEqualToString: @"output"])
	{
	  NSString		*use = [a objectForKey: @"use"];

	  if ([name isEqualToString: @"body"])
	    {
	    }
	  else if ([name isEqualToString: @"header"])
	    {
	      NSString	*part = [a objectForKey: @"part"];
	      NSString	*messageName = [a objectForKey: @"message"];

	      /* If there is no 'message' attribute, we must be using the
	       * message defined by the abstract portType  for this operation.
	       */
	      if (part != nil && messageName == nil)
		{
		  NSString	*name;
		  GWSElement	*elem;

		  /* This is in binding/operation/input/header, so the name
		   * of our parent's parent is the operation name.
		   */
		  name = [[[elem parent] parent] name];
		  elem = [[(GWSBinding*)section type]
		    operationWithName: name create: NO];
		  if (elem == nil)
		    {
		      return [NSString stringWithFormat:
			@"No operation '%@' found in binding", name];
		    }
		  elem = [elem firstChild];
		  while (elem != nil && [[elem name] isEqual: @"input"] == NO)
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

		  message = [document messageWithName: messageName create: NO];
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
	  else
	    {
	      return [NSString stringWithFormat:
		@"unknown SOAP extensibility: '%@' in %@", name, section];
	    }

	  if ([use isEqualToString: @"literal"] == NO
	    && [use isEqualToString: @"encoded"] == NO)
	    {
	      return [NSString stringWithFormat:
		@"bad SOAP 'use' value: '%@' in %@ %@", use, section, name];
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
			in: (id)section
{
  NSString	*problem;
  NSString	*name;
  NSString	*pName;
  NSDictionary	*a;
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
  pName = [[node parent] name];
  a = [node attributes];

  /* Now we do section specific setup.
   */
  if ([section isKindOfClass: [GWSBinding class]])
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
      else if ([name isEqualToString: @"operation"])
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
      else if ([pName isEqualToString: @"input"]
        ||[pName isEqualToString: @"output"])
	{
	  NSDictionary	*a = [node attributes];
	  NSString	*use = [a objectForKey: @"use"];

	  if ([name isEqualToString: @"body"])
	    {
	      NSString			*namespace;
	      NSMutableDictionary	*p = [service webServiceParameters];

	      [p setObject: use forKey: GWSSOAPBodyUseKey];

	      namespace = [a objectForKey: @"namespace"];
	      if (namespace != nil)
		{
	          [p setObject: namespace forKey: GWSSOAPMethodNamespaceURIKey];
		}
	    }
	  else if ([name isEqualToString: @"header"])
	    {
	      [[service webServiceParameters] setObject: use
		forKey: GWSSOAPHeaderUseKey];
	    }
	}
    }
  else if ([section isKindOfClass: [GWSPort class]] == YES)
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
