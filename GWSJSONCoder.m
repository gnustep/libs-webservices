/** 
   Copyright (C) 2011 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	May 2011
   
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

@interface      GWSJSONCoder (Private)

- (void) _appendObject: (id)o;

@end


@implementation	GWSJSONCoder

static NSCharacterSet   *ws;

+ (void) initialize
{
  ws = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (NSData*) buildRequest: (NSString*)method 
              parameters: (NSDictionary*)parameters
                   order: (NSArray*)order
{
  NSMutableString       *ms;
  unsigned	        c;
  id			o;

  [self reset];

  ms = [self mutableString];
  [ms setString: @""];

  o = [parameters objectForKey: GWSOrderKey];
  if (o != nil)
    {
      if (order != nil && [order isEqual: o] == NO)
	{
	  NSLog(@"Parameter order specified both in the 'order' argument and using GWSOrderKey.  Using the value from GWSOrderkey.");
	}
      order = o;
    }

  if ([order count] == 0)
    {
      order = [parameters allKeys];
    }
  c = [order count];
  if (c > 0)
    {
      id	v;

      if (1 == c)
	{
	  v = [parameters objectForKey: [order objectAtIndex: 0]];
	  if (NO == [v isKindOfClass: [NSDictionary class]]
	    && NO == [v isKindOfClass: [NSArray class]])
	    {
	      v = [NSArray arrayWithObject: v]; 
	    }
	  else
	    {
	      v = parameters;
	    }
	}
      else
	{
	  v = parameters;
	}
      [self _appendObject: v];
    }
  return [ms dataUsingEncoding: NSUTF8StringEncoding];
}

- (NSData*) buildResponse: (NSString*)method
               parameters: (NSDictionary*)parameters
                    order: (NSArray*)order;
{
  NSMutableString       *ms;
  unsigned	        c;
  id			o;

  [self reset];

  ms = [self mutableString];
  [ms setString: @""];

  o = [parameters objectForKey: GWSOrderKey];
  if (o != nil)
    {
      if (order != nil && [order isEqual: o] == NO)
	{
	  NSLog(@"Parameter order specified both in the 'order' argument and using GWSOrderKey.  Using the value from GWSOrderkey.");
	}
      order = o;
    }

  if ([order count] == 0)
    {
      order = [parameters allKeys];
    }
  c = [order count];
  if (c > 0)
    {
      id	v;

      if (1 == c)
	{
	  v = [parameters objectForKey: [order objectAtIndex: 0]];
	  if (NO == [v isKindOfClass: [NSDictionary class]]
	    && NO == [v isKindOfClass: [NSArray class]])
	    {
	      v = [NSArray arrayWithObject: v]; 
	    }
	  else
	    {
	      v = parameters;
	    }
	}
      else
	{
	  v = parameters;
	}
      [self _appendObject: v];
    }
  return [ms dataUsingEncoding: NSUTF8StringEncoding];
}

- (NSString*) encodeDateTimeFrom: (NSDate*)source
{
  NSString	*s;

  s = [source descriptionWithCalendarFormat: @"%Y%m%dT%H:%M:%S"
                                   timeZone: [self timeZone]
                                     locale: nil];
  return s;
}

- (NSMutableDictionary*) parseMessage: (NSData*)data
{
  NSAutoreleasePool     *pool;
  NSMutableDictionary   *result;
  NSMutableDictionary   *params;
  NSMutableArray        *order;
  NSString              *name;

  result = [NSMutableDictionary dictionaryWithCapacity: 3];

  [self reset];
  pool = [NSAutoreleasePool new];
  NS_DURING
    {
    }
  NS_HANDLER
    {
      [result setObject: [localException reason] forKey: GWSErrorKey];
    }
  NS_ENDHANDLER

  [self reset];
  [pool release];

  return result;
}

@end

@implementation GWSJSONCoder (Private)

- (NSString*) _jsonString: (NSString*)str
{
  unsigned	length = [str length];
  unsigned	output = 2;
  unichar	*from;
  unsigned	i = 0;
  unichar	*to;
  unsigned	j = 0;

  if (length == 0)
    {
      return @"\"\"";
    }
  from = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * length);
  [str getCharacters: from];

  for (i = 0; i < length; i++)
    {
      unichar	c = from[i];

      if (c == '"' || c == '\\' || c == '\n' || c == '\r' || c == '\t')
	{
	  output += 2;
	}
      else if (c < 0x20)
	{
	  output += 6;
	}
      else
	{
	  output++;
	}
    }

  to = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * output);
  to[j++] = '"';
  for (i = 0; i < length; i++)
    {
      unichar	c = from[i];

      if (c == '"' || c == '\\' || c == '\n' || c == '\r' || c == '\t')
	{
	  to[j++] = '\\';
          switch (c)
	    {
	      case '\\': to[j++] = '\\'; break;
	      case '\n': to[j++] = 'n'; break;
	      case '\r': to[j++] = 'r'; break;
	      case '\t': to[j++] = 't'; break;
	      default: to[j++] = '"'; break;
	    }
	}
      else if (c < 0x20)
	{
	  char	buf[5];

	  to[j++] = '\\';
	  to[j++] = 'u';
	  sprintf(buf, "%04x", c);
	  to[j++] = buf[0];
	  to[j++] = buf[1];
	  to[j++] = buf[2];
	  to[j++] = buf[3];
	}
      else
	{
	  to[j++] = c;
	}
    }
  to[j] = '"';
  str = [[NSString alloc] initWithCharacters: to length: output];
  NSZoneFree (NSDefaultMallocZone (), to);
  [str autorelease];
  NSZoneFree (NSDefaultMallocZone (), from);
  return str;
}

- (void) _appendObject: (id)o
{
  NSMutableString       *ms = [self mutableString];

  if (YES == [o isKindOfClass: [NSNull class]])
    {
      [ms appendString: @"null"];
    }
  else if (YES == [o isKindOfClass: [NSString class]])
    {
      [ms appendString: [self _jsonString: o]];
    }
  else if (YES == [o isKindOfClass: [NSNumber class]])
    {
      const char	*t = [o objCType];

      if (strchr("cCsSiIlL", *t) != 0)
        {
          long long	i = [(NSNumber*)o longLongValue];

          if ((i == 0 || i == 1) && (*t == 'c' || *t == 'C'))
            {
              if (i == 0)
                {
                  [ms appendString: @"true"];
                }
              else
                {
                  [ms appendString: @"false"];
                }
            }
          else
            {
              [ms appendFormat: @"%lld", i];
            }
        }
      else
        {
          [ms appendFormat: @"%f", [(NSNumber*)o doubleValue]];
        }
    }
  else if (YES == [o isKindOfClass: [NSData class]])
    {
      [ms appendString: @"\""];
      [ms appendString: [self encodeBase64From: o]];
      [ms appendString: @"\""];
    }
  else if (YES == [o isKindOfClass: [NSDate class]])
    {
      [ms appendString: @"\""];
      [ms appendString: [self encodeDateTimeFrom: o]];
      [ms appendString: @"\""];
    }
  else if (YES == [o isKindOfClass: [NSArray class]])
    {
      unsigned 		i;
      unsigned		c = [o count];
      
      [self nl];
      [ms appendString: @"["];
      [self nl];
      [self indent];
      for (i = 0; i < c; i++)
        {
	  if (i > 0)
	    {
	      [ms appendString: @","];
	    }
          [self nl];
          [self _appendObject: [o objectAtIndex: i]];
        }
      [self unindent];
      [self nl];
      [ms appendString: @"]"];
    }
  else if (YES == [o isKindOfClass: [NSDictionary class]])
    {
      NSEnumerator	*kEnum;
      NSString	        *key;

      kEnum = [[o objectForKey: GWSOrderKey] objectEnumerator];
      if (kEnum == nil)
        {
          kEnum = [o keyEnumerator];
        }
      [self nl];
      [ms appendString: @"{"];
      [self indent];
      while ((key = [kEnum nextObject]))
        {
          [ms appendString: [self escapeXMLFrom: [key description]]];
          [ms appendString: @":"];
          [self nl];
          [self _appendObject: [o objectForKey: key]];
          [self nl];
        }
      [self unindent];
      [self nl];
      [ms appendString: @"}"];
    }
  else
    {
      [self _appendObject: [o description]];
    }
}

@end


