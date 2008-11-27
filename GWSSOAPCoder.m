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

#import <Foundation/Foundation.h>
#import "GWSPrivate.h"

NSString * const GWSSOAPBodyEncodingStyleKey
  = @"GWSSOAPBodyEncodingStyleKey";
NSString * const GWSSOAPBodyEncodingStyleDocument
  = @"GWSSOAPBodyEncodingStyleDocument";
NSString * const GWSSOAPBodyEncodingStyleRPC
  = @"GWSSOAPBodyEncodingStyleRPC";
NSString * const GWSSOAPBodyEncodingStyleWrapped
  = @"GWSSOAPBodyEncodingStyleWrapped";
NSString * const GWSSOAPBodyUseKey
  = @"GWSSOAPBodyUseKey";
NSString * const GWSSOAPHeaderUseKey
  = @"GWSSOAPHeaderUseKey";
NSString * const GWSSOAPMethodNamespaceURIKey
  = @"GWSSOAPMethodNamespaceURIKey";
NSString * const GWSSOAPMethodNamespaceNameKey
  = @"GWSSOAPMethodNamespaceNameKey";
NSString * const GWSSOAPMessageHeadersKey
  = @"GWSSOAPMessageHeadersKey";

@interface      GWSSOAPCoder (Private)

- (GWSElement*) _elementForObject: (id)o named: (NSString*)name;
- (id) _simplify: (GWSElement*)elem;

@end

@implementation	GWSSOAPCoder

- (NSData*) buildRequest: (NSString*)method 
              parameters: (NSDictionary*)parameters
                   order: (NSArray*)order
{
  NSString              *nsName;
  NSString              *nsURI;
  GWSElement            *envelope;
  GWSElement            *header;
  GWSElement            *body;
  GWSElement            *container;
  NSString              *prefix;
  NSString              *qualified;
  NSString		*use;
  NSMutableString       *ms;
  id			o;
  unsigned	        c;
  unsigned	        i;

  /* The method name is required for RPC operations ...
   * for document style operations the method is implicit in the URL
   * that the document is sent to.
   * We therefore check the method name only if we are doing an RPC.
   */
  if (_style == GWSSOAPBodyEncodingStyleRPC && [self fault] == NO)
    {
      if ([method length] == 0)
	{
	  return nil;
	}
      else
	{
	  static NSCharacterSet	*illegal = nil;
	  NSRange			r;

	  if (illegal == nil)
	    {
	      NSMutableCharacterSet	*tmp = [NSMutableCharacterSet new];

	      [tmp addCharactersInRange: NSMakeRange('0', 10)];
	      [tmp addCharactersInRange: NSMakeRange('a', 26)];
	      [tmp addCharactersInRange: NSMakeRange('A', 26)];
	      [tmp addCharactersInString: @"_.:/"];
	      [tmp invert];
	      illegal = [tmp copy];
	      [tmp release];
	    }
	  r = [method rangeOfCharacterFromSet: illegal];
	  if (r.length > 0)
	    {
	      return nil;	// Bad method name.
	    }
	}
    }

  envelope = [[GWSElement alloc] initWithName: @"Envelope"
                                    namespace: nil
                                    qualified: @"soapenv:Envelope"
                                   attributes: nil];
  [envelope autorelease];
  [envelope setNamespace: @"http://schemas.xmlsoap.org/soap/envelope/"
              forKey: @"soapenv"];
  [envelope setNamespace: @"http://www.w3.org/2001/XMLSchema"
              forKey: @"xsd"];
  [envelope setNamespace: @"http://www.w3.org/2001/XMLSchema-instance"
              forKey: @"xsi"];

  /* Check the method namespace ... if we have a URI and a name then we
   * want to specify the namespace in the envelope.
   */
  nsName = [parameters objectForKey: GWSSOAPMethodNamespaceNameKey];
  nsURI = [parameters objectForKey: GWSSOAPMethodNamespaceURIKey];
  if (_style == GWSSOAPBodyEncodingStyleRPC && nsName != nil && nsURI != nil)
    {
      [envelope setNamespace: nsURI forKey: nsName];
    }

  if ([self delegate] != nil)
    {
      envelope = [[self delegate] coder: self willEncode: envelope];
    }
  if ([[envelope qualified] isEqualToString: @"Envelope"])
    {
      prefix = nil;
    }
  else
    {
      prefix = [envelope qualified];
      prefix = [prefix substringToIndex: [prefix rangeOfString: @":"].location];
    }

  /* See if we have a key in the parameters to specify how the header
   * should be encoded.
   */
  use = [parameters objectForKey: GWSSOAPHeaderUseKey];
  if ([use isEqualToString: @"literal"] == YES)
    {
      [self setUseLiteral: YES];
    }
  else if ([use isEqualToString: @"encoded"] == YES)
    {
      [self setUseLiteral: NO];
    }

  /* Now look for a value listing the headers to be encoded.
   * If there is no value, we omit the SOAP header entirely.
   */
  o = [parameters objectForKey: GWSSOAPMessageHeadersKey];
  if (o != nil)
    {
      qualified = @"Header";
      if (prefix != nil)
        {
          qualified = [NSString stringWithFormat: @"%@:%@", prefix, qualified];
        }
      header = [[GWSElement alloc] initWithName: @"Header"
                                      namespace: nil
                                      qualified: qualified
                                     attributes: nil];
      [envelope addChild: header];
      [header release];
      if ([o isKindOfClass: [NSArray class]] && [o count] > 0)
	{
	  NSArray	*a = (NSArray*)o;

          c = [a count];
	  /* The array contains XML nodes ... just add them to the
	   * header we are going to write.
	   */
	  for (i = 0; i < c; i++)
	    {
	      o = [a objectAtIndex: i];
	      if ([o isKindOfClass: [GWSElement class]] == NO)
		{
		  [NSException raise: NSInvalidArgumentException
			      format: @"Header element %d wrong class: '%@'",
		    i, NSStringFromClass([o class])];
		}
	      [header addChild: o];
	    }
	}
      else if ([o isKindOfClass: [NSDictionary class]] && [o count] > 0)
	{
	  NSDictionary	*d = (NSDictionary*)o;
	  NSArray	*a = [o objectForKey: GWSOrderKey];

	  if (a == nil)
	    {
	      a = [d allKeys];
	    }
          c = [a count];
	
	  /* The dictionary contains header elements by name.
	   */
	  for (i = 0; i < c; i++)
	    {
	      NSString          *k = [a objectAtIndex: i];
	      id                v = [d objectForKey: k];
	      GWSElement        *e;

	      if (v == nil)
		{
		  [NSException raise: NSInvalidArgumentException
			      format: @"Header '%@' missing", k];
		}
	      e = [[self delegate] encodeWithCoder: self
					      item: v
					     named: k
					     index: NSNotFound];
	      if (e == nil)
		{
		  e = [self _elementForObject: v named: k];
		}
	      [header addChild: e];
	    }
	}
    }

  /* Now we give the delegate a chance to entirely replace the header
   * with an element of its own.
   */
  if ([self delegate] != nil)
    {
      GWSElement        *elem;

      elem = [[self delegate] coder: self willEncode: header];
      if (elem != header)
        {
          [header remove];
          header = elem;
          [envelope addChild: header];
        }
    }

  /* See if we have a key in the parameters to specify how the body
   * should be encoded.
   */
  use = [parameters objectForKey: GWSSOAPBodyUseKey];
  if ([use isEqualToString: @"literal"] == YES)
    {
      [self setUseLiteral: YES];
    }
  else if ([use isEqualToString: @"encoded"] == YES)
    {
      [self setUseLiteral: NO];
    }

  qualified = @"Body";
  if (prefix != nil)
    {
      qualified = [NSString stringWithFormat: @"%@:%@", prefix, qualified];
    }
  body = [[GWSElement alloc] initWithName: @"Body"
                                namespace: nil
                                qualified: qualified
                               attributes: nil];
  [envelope addChild: body];
  [body release];
  if ([self delegate] != nil)
    {
      GWSElement        *elem;

      elem = [[self delegate] coder: self willEncode: body];
      if (elem != body)
        {
          [body remove];
          body = elem;
          [envelope addChild: body];
        }
    }

  if ([self fault] == YES)
    {
      GWSElement	*fault;

      qualified = @"Fault";
      if (prefix != nil)
	{
	  qualified = [NSString stringWithFormat: @"%@:%@", prefix, qualified];
	}
      fault = [[GWSElement alloc] initWithName: @"Fault"
				     namespace: nil
				     qualified: qualified
				    attributes: nil];
      [body addChild: fault];
      [fault release];
      if ([self delegate] != nil)
	{
	  GWSElement        *elem;

	  elem = [[self delegate] coder: self willEncode: fault];
	  if (elem != fault)
	    {
	      [fault remove];
	      fault = elem;
	      [body addChild: fault];
	    }
	}

      if ([order count] == 0)
	{
	  NSEnumerator      *kEnum = [parameters keyEnumerator];
	  NSString          *k;
	  NSMutableArray    *a = [NSMutableArray array];

	  while ((k = [kEnum nextObject]) != nil)
	    {
	      if ([k hasPrefix: @"GWSSOAP"])
		{
		}
	      else
		{
		  [a addObject: k];
		}
	    }
	  order = a;
	}
      c = [order count];
      for (i = 0; i < c; i++)
	{
	  NSString          *k = [order objectAtIndex: i];
	  id                v = [parameters objectForKey: k];
	  GWSElement        *e;

	  e = [[self delegate] encodeWithCoder: self
					  item: v
					 named: k
					 index: i];
	  if (e == nil)
	    {
	      e = [self _elementForObject: v named: k];
	    }
	  [fault addChild: e];
	}
    }
  else
    {
      if (_style == GWSSOAPBodyEncodingStyleRPC)
	{
	  if (nsName == nil)
	    {
	      qualified = method;
	    }
	  else
	    {
	      qualified = [NSString stringWithFormat: @"%@:%@", nsName, method];
	    }
	  container = [[GWSElement alloc] initWithName: method
					     namespace: nsName
					     qualified: qualified
					    attributes: nil];
	  [body addChild: container];
	  [container release];
	  qualified = @"encodingStyle";
	  if (prefix != nil)
	    {
	      qualified = [NSString stringWithFormat: @"%@:%@",
		prefix, qualified];
	    }
	  [container setAttribute: @"http://schemas.xmlsoap.org/soap/encoding/"
			   forKey: qualified];

	  if (nsURI != nil && nsName == nil)
	    {
	      /* We have a namespace but no name ... make it the default
	       * namespace for the body.
	       */
	      [container setNamespace: nsURI forKey: @""];
	    }

	  if ([self delegate] != nil)
	    {
	      GWSElement        *elem;

	      elem = [[self delegate] coder: self willEncode: container];
	      if (elem != container)
		{
		  [container remove];
		  container = elem;
		  [body addChild: container];
		}
	    }
	}
      else if (_style == GWSSOAPBodyEncodingStyleWrapped)
	{
	  NSLog(@"FIXME GWSSOAPBodyEncodingStyleWrapped not implemented");
	  container = body;
	}
      else
	{
	  container = body;    // Direct encoding inside the body.
	}

      if ([order count] == 0)
	{
	  NSEnumerator      *kEnum = [parameters keyEnumerator];
	  NSString          *k;
	  NSMutableArray    *a = [NSMutableArray array];

	  while ((k = [kEnum nextObject]) != nil)
	    {
	      if ([k hasPrefix: @"GWSSOAP"] == YES)
		{
		  if ([k isEqual: GWSSOAPBodyEncodingStyleKey])
		    {
		      NSString      *v = [parameters objectForKey: k];

		      [self setOperationStyle: v];
		    }
		}
	      else
		{
		  [a addObject: k];
		}
	    }
	  order = a;
	}
      c = [order count];
      for (i = 0; i < c; i++)
	{
	  NSString          *k = [order objectAtIndex: i];
	  id                v = [parameters objectForKey: k];
	  GWSElement        *e;

	  if (v == nil)
	    {
	      [NSException raise: NSInvalidArgumentException
			  format: @"Value '%@' (order %u) missing", k, i];
	    }
	  e = [[self delegate] encodeWithCoder: self
					  item: v
					 named: k
					 index: i];
	  if (e == nil)
	    {
	      e = [self _elementForObject: v named: k];
	    }
	  [container addChild: e];
	}
    }

  ms = [self mutableString];
  [ms setString: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
  [envelope encodeWith: self];
  return [ms dataUsingEncoding: NSUTF8StringEncoding];
}

- (NSData*) buildResponse: (NSString*)method
               parameters: (NSDictionary*)parameters
                    order: (NSArray*)order;
{
  /* For SOAP a request and a response look the same ... both are just
   * messages.
   */
  return [self buildRequest: method parameters: parameters order: order];
}

- (NSString*) encodeDateTimeFrom: (NSDate*)source
{
  NSTimeZone    *tz;

  if ([source isKindOfClass: [NSCalendarDate class]] == YES)
    {
      tz = [(NSCalendarDate*)source timeZone];
    }
  else
    {
      tz = [self timeZone];
    }
  source = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:
    [source timeIntervalSinceReferenceDate]];
  [(NSCalendarDate*)source setTimeZone: tz];
  if ([tz secondsFromGMT] != 0)
    {
      [(NSCalendarDate*)source setCalendarFormat: @"%Y-%m-%dT%H:%M:%S%z"];
    }
  else
    {
      [(NSCalendarDate*)source setCalendarFormat: @"%Y-%m-%dT%H:%M:%SZ"];
    }
  return [source description];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      _style = GWSSOAPBodyEncodingStyleDocument;
    }
  return self;
}

- (NSString*) operationStyle
{
  return _style;
}

- (NSMutableDictionary*) parseMessage: (NSData*)data
{
  NSAutoreleasePool     *pool;
  NSMutableDictionary   *result;

  result = [NSMutableDictionary dictionaryWithCapacity: 3];
  pool = [NSAutoreleasePool new];

  NS_DURING
    {
      GWSCoder                  *parser;
      NSEnumerator              *enumerator;
      GWSElement                *elem;
      GWSElement                *envelope;
      GWSElement                *header;
      GWSElement                *body;
      NSMutableDictionary       *p;
      NSMutableArray            *o;
      NSArray                   *children;
      unsigned                  c;
      unsigned                  i;

      envelope = nil;
      header = nil;
      body = nil;

      parser = [[GWSCoder new] autorelease];
      envelope = [parser parseXML: data];
      if (envelope == nil)
	{
          [NSException raise: NSInvalidArgumentException
                      format: @"Document is NOT parsable as XML"];
	}
      if ([self delegate] != nil)
        {
          envelope = [[self delegate] coder: self willDecode: envelope];
        }

      if ([[envelope name] isEqualToString: @"Envelope"] == NO)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Document is not Envelope but '%@'",
                      [envelope name]];
        }

      enumerator = [[envelope children] objectEnumerator];
      elem = [enumerator nextObject];
      if (elem == nil)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Envelope is empty"];
        }

      if ([[elem name] isEqualToString: @"Header"] == YES)
        {
          header = elem;
          elem = [enumerator nextObject];
          if ([self delegate] != nil)
            {
              header = [[self delegate] coder: self willDecode: header];
            }
        }
      if (elem == nil)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Envelope contains no Body"];
        }
      else if ([[elem name] isEqualToString: @"Body"] == NO)
        {
          [NSException raise: NSInvalidArgumentException
                      format: @"Envelope contains '%@' where Body was expected",
                      [elem name]];
        }
      body = elem;
      if ([self delegate] != nil)
        {
          body = [[self delegate] coder: self willDecode: body];
        }

      children = [body children];
      c = [children count];
      elem = [children lastObject];
      if (c == 1 && [[elem name] isEqualToString: @"Fault"] == YES)
        {
          NSMutableDictionary   *f;
          GWSElement            *fault = elem;

          f = [[NSMutableDictionary alloc] initWithCapacity: 4];
          [result setObject: f forKey: GWSFaultKey];
          [f release];

          if ([self delegate] != nil)
            {
              fault = [[self delegate] coder: self willDecode: fault];
            }
          children = [fault children];
          c = [children count];
          i = 0;
          while (i < c)
            {
              NSString          *n;
              NSString          *v;

              elem = [children objectAtIndex: i++];
              n = [elem name];
              v = [elem content];
              if ([n isEqualToString: @"faultcode"] == YES && v != nil)
                {
                  [f setObject: v forKey: @"faultcode"];
                }
              else if ([n isEqualToString: @"faultstring"] == YES)
                {
                  /* faultstring must be present but may be empty. */
                  if (v == nil)
                    {
                      v = @"";
                    }
                  [f setObject: v forKey: @"faultstring"];
                }
              else if ([n isEqualToString: @"faultactor"] == YES && v != nil)
                {
                  [f setObject: v forKey: @"faultactor"];
                }
              else if ([n isEqualToString: @"detail"] == YES)
                {
                  if (v != nil)
                    {
                      [f setObject: v forKey: @"detail"];
                    }
                  else
                    {
                      id        arg;

                      arg = [[self delegate] decodeWithCoder: self
                                                        item: elem
                                                       named: n
                                                       index: i];
                      if (arg == nil)
                        {
                          /*
                           * FIXME ... convert subelements to the sort of type
                           * we should really have.
                           */
                          arg = [self _simplify: elem];
                        }
                      [f setObject: arg forKey: @"detail"];
                    }
                }
            }
        }
      else
        {
          /* If the body contains a single element with no content,
           * we assume it is a method and its children are the
           * parameters.  Otherwise we assume that the parameters
           * are found directly inside the body.
           */
          if (c == 1 && [elem content] == nil)
            {
              if ([self delegate] != nil)
                {
                  elem = [[self delegate] coder: self willDecode: elem];
                }
              [result setObject: [elem name] forKey: GWSMethodKey];
              children = [elem children];
            }
          p = [[NSMutableDictionary alloc] initWithCapacity: c];
          [result setObject: p forKey: GWSParametersKey];
          [p release];
          o = [[NSMutableArray alloc] initWithCapacity: c];
          [result setObject: o forKey: GWSOrderKey];
          [o release];
          c = [children count];
          for (i = 0; i < c; i++)
            {
              id                arg;
              NSString          *n;

              elem = [children objectAtIndex: i];
              n = [elem name];
              [o addObject: n];
              arg = [[self delegate] decodeWithCoder: self
                                                item: elem
                                               named: n
                                               index: i];
              if (arg == nil)
                {
                  arg = [self _simplify: elem];
                }
              [p setObject: arg forKey: n];
            }
        }
    }
  NS_HANDLER
    {
      [result setObject: [localException description] forKey: GWSErrorKey];
    }
  NS_ENDHANDLER
  [pool release];

  return result;
}

- (void) setOperationStyle: (NSString*)style
{
  if ([GWSSOAPBodyEncodingStyleDocument isEqualToString: style])
    {
      _style = GWSSOAPBodyEncodingStyleDocument;
    }
  else if ([GWSSOAPBodyEncodingStyleWrapped isEqualToString: style])
    {
      _style = GWSSOAPBodyEncodingStyleWrapped;
    }
  else if ([GWSSOAPBodyEncodingStyleRPC isEqualToString: style])
    {
      _style = GWSSOAPBodyEncodingStyleRPC;
    }
}

- (void) setUseLiteral: (BOOL)use
{
  _useLiteral = use;
}

- (BOOL) useLiteral
{
  return _useLiteral;
}

@end

@implementation GWSSOAPCoder (Private)

- (GWSElement*) _elementForObject: (id)o named: (NSString*)name
{
  GWSElement    *e;
  NSString      *q;     // Qualified name
  NSString      *x;     // xsi:type if any
  NSString      *c;     // Content if any
  BOOL          array = NO;
  BOOL          dictionary = NO;

  if (o == nil)
    {
      return nil;
    }

  x = nil;
  c = nil;
  q = name;

  if (YES == [o isKindOfClass: [NSString class]])
    {
      if (NO == _useLiteral)
        {
          x = @"xsd:string";
        }
      c = o;
    }
  else if (YES == [o isKindOfClass: [NSNumber class]])
    {
      const char	*t = [o objCType];

      if (strchr("cCsSiIlL", *t) != 0)
        {
          long	i = [(NSNumber*)o longValue];

          if ((i == 0 || i == 1) && (*t == 'c' || *t == 'C'))
            {
              if (NO == _useLiteral)
                {
                  x = @"xsd:boolean";
                }
              if (i == 0)
                {
                  c = @"false";
                }
              else
                {
                  c = @"true";
                }
            }
          else
            {
              if (NO == _useLiteral)
                {
                  x = @"xsd:int";
                }
              c = [NSString stringWithFormat: @"%ld", i];
            }
        }
      else
        {
          if (NO == _useLiteral)
            {
              x = @"xsd:double";
            }
          c = [NSString stringWithFormat: @"%f", [(NSNumber*)o doubleValue]];
        }
    }
  else if (YES == [o isKindOfClass: [NSData class]])
    {
      if (NO == _useLiteral)
        {
          x = @"xsd:base64Binary";
        }
      c = [self encodeBase64From: o];
    }
  else if (YES == [o isKindOfClass: [NSDate class]])
    {
      if (NO == _useLiteral)
        {
          x = @"xsd:timeInstant";
        }
      c = [self encodeDateTimeFrom: o];
    }
  else if (YES == [o isKindOfClass: [NSDictionary class]])
    {
      dictionary = YES;
    }
  else if (YES == [o isKindOfClass: [NSArray class]])
    {
      array = YES;
    }
  else
    {
      if (NO == _useLiteral)
        {
          x = @"xsd:string";
        }
      c = [o description];
    }
  e = [[GWSElement alloc] initWithName: name
                             namespace: nil
                             qualified: q
                            attributes: nil];
  if (x != nil)
    {
      [e setAttribute: x forKey: @"xsi:type"];
    }
  if (c != nil)
    {
      [e addContent: c];
    }
  if (dictionary == YES)
    {
      NSArray   *order = [o objectForKey: GWSOrderKey];
      unsigned  count;
      unsigned  i;

      if ([order count] == 0)
        {
          order = [o allKeys];
        }
      count = [order count];
      for (i = 0; i < count; i++)
        {
          NSString      *k = [order objectAtIndex: i];
          id            v = [o objectForKey: k];

	  if (v == nil)
	    {
	      [NSException raise: NSInvalidArgumentException
			  format: @"Parameter '%@' (order %u) missing", k, i];
	    }
	  [e addChild: [self _elementForObject: v named: k]];
        }
    }
  if (array == YES)
    {
      unsigned  count;
      unsigned  i;

      count = [o count];
      for (i = 0; i < count; i++)
        {
          NSString      *k;
          id            v = [o objectAtIndex: i];

          k = [NSString stringWithFormat: @"Arg%u", i];
          [e addChild: [self _elementForObject: v named: k]];
        }
    }
  return [e autorelease];
}

- (id) _simplify: (GWSElement*)elem
{
  NSArray       *a;
  unsigned      c;
  id            result;

  a = [elem children];
  c = [a count];
  if (c == 0)
    {
      NSString  *t;

      /* No child elements ... use the content of this element
       * or an empty string if there was no content.
       */
      result = [elem content];
      if (result == nil)
        {
          result = @"";
        }
      t = [[elem attributes] objectForKey: @"xsi:type"];
      if (t != nil)
        {
          /* Parse simple builtin types from xsd
           */
          if ([t isEqualToString: @"xsd:string"] == YES)
            {
            }
          else if ([t isEqualToString: @"xsd:int"] == YES
            || [t isEqualToString: @"xsd:integer"] == YES)
            {
              result = [NSNumber numberWithInt: [result intValue]];
            }
          else if ([t isEqualToString: @"xsd:boolean"] == YES)
            {
              if ([result isEqualToString: @"true"]
                || [result isEqualToString: @"1"])
                {
                  result = [NSNumber numberWithBool: YES];
                }
              else
                {
                  result = [NSNumber numberWithBool: NO];
                }
            }
          else if ([t isEqualToString: @"xsd:base64Binary"] == YES)
            {
              result = [self decodeBase64From: result];
            }

#if 0
          else if ([t isEqualToString: @"xsd:hexBinary"] == YES)
            {
              result = [self decodeHexFrom: result];
            }
#endif
          else if ([t isEqualToString: @"xsd:dateTime"] == YES
            || [t isEqualToString: @"xsd:timeInstant"] == YES)
            {
              NSTimeZone        *tz;
              const char	*s;
              int		year;
              int		month;
              int		day;
              int		hour;
              int		minute;
              int		second;

              s = [result UTF8String];
              if (s != 0 && *s == '-')
                {
                  s++;          // Leading '-' in year is ignored.
                }
              if (sscanf(s, "%d-%d-%dT%d:%d:%d",
                &year, &month, &day, &hour, &minute, &second) != 6)
                {
                  [NSException raise: NSInvalidArgumentException
                              format: @"bad date/time format '%@'", result];
                }
              s = strchr(s, ':');
              s++;
              s = strchr(s, ':');
              while (isdigit(*s)) s++;
              if (*s == 'Z')
                {
                  tz = [NSTimeZone timeZoneForSecondsFromGMT: 0];
                }
              else if (*s == '+' || *s == '-')
                {
                  int   zh = (s[1] - '0') * 10 + s[2] - '0';
                  int   zm = (s[3] - '0') * 10 + s[4] - '0';
                  int   zs = ((zh * 60) + zm) * 60;

                  if (*s == '-')
                    {
                      zs = - zs;
                    }
                  tz = [NSTimeZone timeZoneForSecondsFromGMT: zs];
                }
              else
                {
                  tz = [self timeZone];
                }

              result = [[NSCalendarDate alloc] initWithYear: year
                                                      month: month
                                                        day: day
                                                       hour: hour
                                                     minute: minute
                                                     second: second 
                                                   timeZone: tz]; 
            }
          else if ([t isEqualToString: @"xsd:double"] == YES)
            {
              result = [NSNumber numberWithDouble: [result doubleValue]];
            }
        }
    }
  else
    {
      NSMutableArray            *ma;
      NSMutableDictionary       *md;
      unsigned                  i;

      md = [NSMutableDictionary dictionaryWithCapacity: c];
      ma = [NSMutableArray arrayWithCapacity: c];
      for (i = 0; i < c; i++)
        {
          NSString      *n;
          id            o;

          elem = [a objectAtIndex: i];
          n = [elem name];
          o = [self _simplify: elem];
          [md setObject: o forKey: n];
          [ma addObject: o];
        }
      if ([md count] == c)
        {
          /* As the dictionary contains an entry for each object decoded,
           * then all objects had different names and this is a structure.
           */
          result = md;
        }
      else
        {
          /* As the dictionary contains a different number of objects to
           * the number decoded, some must have had the same name and we
           * therefore have an array.
           */
          result = ma;
        }
    }
  return result;
}

@end


@implementation NSObject (GWSSOAPCoder)

- (GWSElement*) coder: (GWSSOAPCoder*)coder willDecode: (GWSElement*)element
{
  return element;
}

- (GWSElement*) coder: (GWSSOAPCoder*)coder willEncode: (GWSElement*)element
{
  return element;
}

@end

