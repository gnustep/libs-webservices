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

/** Function to look up and return a mutable dictionary from within a
 * mutable dictionary.  If an immutable dictionary is found, it is
 * converted to a mutable one.
 */
static NSMutableDictionary *
mutable(NSMutableDictionary *d, NSString *k)
{
  id	o = [d objectForKey: k];

  if ([o isKindOfClass: [NSDictionary class]] == NO)
    {
      return nil;
    }
  if ([o isKindOfClass: [NSMutableDictionary class]] == NO)
    {
      o = [o mutableCopy];
      [d setObject: o forKey: k];
      [o release];
    }
  return o;
}

/** Function to look up a non-dictionary value from within a
 * mutable dictionary and convert it to a mutable dictionary
 * containing the original.<br />
 * If the value found is actually a dictionary, just
 * returns that (made mutable if necessary).
 */
static NSMutableDictionary *
promote(NSMutableDictionary *d, NSString *k)
{
  id	o = mutable(d, k);

  if (o == nil)
    {
      o = [d objectForKey: k];
      if (o != nil)
	{
	  o = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
	    o, GWSSOAPValueKey,
	    nil];
	  [d setObject: o forKey: k];
	  [o release];
	}
    }
  return o;
}


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
	  if ([action length] == 0)
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
	  NSString		*part;
	  NSString		*messageName;
	  GWSMessage		*message;
	  BOOL			literal;

	  if ([use isEqualToString: @"literal"] == YES)
	    {
	      literal = YES;
	    }
	  else if ([use isEqualToString: @"encoded"] == YES)
	    {
	      literal = NO;
	    }
	  else
	    {
	      return [NSString stringWithFormat:
		@"bad SOAP 'use' value: '%@' in %@ %@", use, section, name];
	    }

	  /* If there is no 'message' attribute (it's optional in a header
	   * and not present in a body, we must be using the message defined
	   * by the abstract portType for this operation.
	   */
	  messageName = [a objectForKey: @"message"];
	  if (messageName == nil)
	    {
	      NSString		*name;
	      GWSElement	*elem;

	      /* This is in binding/operation/input/xxx, so the name
	       * attribute of the operatio n element is the namer of
	       * the operation we need to use.
	       */
	      name = [[[[node parent] parent] attributes]
		objectForKey: @"name"];
	      elem = [[(GWSBinding*)section type] operationWithName: name
							     create: NO];
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
		  messageName = [[elem attributes] objectForKey: @"message"];
		}
	      if (messageName == nil)
		{
		  return [NSString stringWithFormat:
		    @"No message for '%@' found in binding", name];
		}
	    }
	  message = [document messageWithName: messageName create: NO];
	  if (message == nil)
	    {
	      return [NSString stringWithFormat:
		@"Unable to find message '%@'", messageName];
	    }

	  if ([name isEqualToString: @"body"])
	    {
	      NSMutableArray	*order;
	      NSArray		*parts;
	      NSEnumerator	*enumerator;

	      [p setObject: use forKey: GWSSOAPUseKey];
	      if (namespace != nil)
		{
	          [p setObject: namespace forKey: GWSSOAPNamespaceURIKey];
		}

	      parts = [[a objectForKey: @"parts"]
		componentsSeparatedByString: @" "];
	      if ([parts count] == 0)
		{
		  parts = [message partNames];
		  if ([parts count] == 0)
		    {
		      return [NSString stringWithFormat:
		        @"no parts in body in %@", section];
		    }
		}
	      order = [NSMutableArray arrayWithCapacity: [parts count]];
	      enumerator = [parts objectEnumerator];
	      while ((part = [enumerator nextObject]) != nil)
		{
		  NSString	*elementName;
		  NSString	*typeName;
		  NSString	*prefix;
		  NSArray	*a;

		  elementName = [message elementOfPartNamed: part];
		  if (elementName == nil)
		    {
		      typeName = [message typeOfPartNamed: part];
		    }
		  else
		    {
		      typeName = nil;
		    }
		  if (elementName == nil && typeName == nil)
		    {
		      return [NSString stringWithFormat:
			@"Unable to find part '%@' in message '%@'",
			part, messageName];
		    }
		  a = [elementName componentsSeparatedByString: @":"];
		  if ([a count] == 2)
		    {
		      prefix = [a objectAtIndex: 0];
		      elementName = [a lastObject];
		    }
		  else
		    {
		      prefix = nil;
		    }
		  if (p != nil)
		    {
		      /* FIXME ... what if there is no value for this
		       * part ... which parts are mandatory?
		       */
		      if (elementName != nil)
			{
			  if ([p objectForKey: elementName] != nil)
			    {
			      [order addObject: elementName];
			    }
			  if (prefix != nil &&  literal == YES)
			    {
			      NSMutableDictionary	*v;
			      NSString		*n;

			      v = promote(p, elementName);
			      n = [document namespaceForPrefix: prefix];
			      [v setObject: n
				    forKey: GWSSOAPNamespaceURIKey];
			    }
			}
		      else
			{
			  if ([p objectForKey: part] != nil)
			    {
			      [order addObject: part];
			    }
			  if (prefix != nil &&  literal == YES)
			    {
			      NSMutableDictionary	*v;
			      NSString		*n;

			      v = promote(p, part);
			      n = [document namespaceForPrefix: prefix];
			      [v setObject: n
				    forKey: GWSSOAPNamespaceURIKey];
			    }
			}
		    }
		}
#if	0
	      if (p != nil)
		{
		  NSString	*n;

		  [p setObject: order forKey: GWSOrderKey];
		  enumerator = [p keyEnumerator];
		  while ((n = [enumerator nextObject]) != nil)
		    {
		      if ([n isEqualToString: GWSOrderKey] == NO
			&& [n hasPrefix: @"GWSSOAP"] == NO
			&& [order containsObject: n] == NO)
			{
			  return [NSString stringWithFormat:
			    @"Unknown value '%@' in message '%@'"
			    @" with parameters %@",
			    n, messageName, p];
			}
		    }
		}
#else
	      if (p != nil)
		{
		  NSString	*n;

		  [p setObject: order forKey: GWSOrderKey];
		  enumerator = [p keyEnumerator];
		  while ((n = [enumerator nextObject]) != nil)
		    {
		      if ([n isEqualToString: GWSOrderKey] == NO
			&& [n hasPrefix: @"GWSSOAP"] == NO
			&& [order containsObject: n] == NO)
			{
			  NSLog(@"Unknown value '%@' in message '%@'"
			    @" with parameters %@",
			    n, messageName, p);
			}
		    }
		}
#endif
	    }
	  else if ([name isEqualToString: @"header"])
	    {
	      NSMutableDictionary	*h;
	      BOOL			created = NO;
	      unsigned			added = 0;

	      /* Get headers dictionary from parameters or create it
	       * if it's not present.
	       */
	      h = mutable(p, GWSSOAPMessageHeadersKey);
	      if (h == nil)
		{
		  created = YES;
		  h = [NSMutableDictionary new];
		}

	      [h setObject: use forKey: GWSSOAPUseKey];
	      if (namespace != nil)
		{
		  [h setObject: namespace forKey: GWSSOAPNamespaceURIKey];
		}
	      part = [a objectForKey: @"part"];
	      if (part)
		{
		  NSString	*elementName;
		  NSString	*typeName;
		  NSString	*partName;
		  NSString	*prefix;
		  NSArray	*a;
		  id		o;

		  elementName = [message elementOfPartNamed: part];
		  if (elementName == nil)
		    {
		      typeName = [message typeOfPartNamed: part];
		      partName = part;
		    }
		  else
		    {
		      typeName = nil;
		      partName = elementName;
		    }
		  if (partName == nil)
		    {
		      return [NSString stringWithFormat:
			@"Unable to find part '%@' in message '%@'",
			part, messageName];
		    }
		  a = [elementName componentsSeparatedByString: @":"];
		  if ([a count] == 2)
		    {
		      prefix = [a objectAtIndex: 0];
		      elementName = [a lastObject];
		    }
		  else
		    {
		      prefix = nil;
		    }

		  o = [h objectForKey: partName];
		  if (o == nil)
		    {
		      /* No value found in headers dictionary, perhaps it's in
		       * the main parameters dictionary and we should move it.
		       */
		      o = [p objectForKey: partName];
		      if (o != nil && [[p objectForKey: GWSOrderKey]
			containsObject: partName] == NO)
			{
			  [h setObject: o forKey: partName];
			  [p removeObjectForKey: elementName];
			}
		    }
		  /* FIXME ... what if there is no value ... is it ok to
		   * just ignore it?
		   */
		  if (o != nil)
		    {
		      added++;

		      /* If the element has a namespace and we are doing
		       * use=literal then we should make sure that the
		       * element is encoded with the namespace.
		       */
		      if (prefix != nil && literal == YES)
			{
			  NSString		*n;
			  NSMutableDictionary	*v;

			  n = [document namespaceForPrefix: prefix];
			  v = promote(h, elementName);
			  [v setObject: n forKey: GWSSOAPNamespaceURIKey];
			}
		    }

		  if (created == YES)
		    {
		      if (added > 0)
			{
			  [p setObject: h forKey: GWSSOAPMessageHeadersKey];
			} 
		      [h release];
		    }
		}
	      else
		{
		  return [NSString stringWithFormat:
		    @"no part in header in %@", section];
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
