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

typedef struct {
  const unsigned char	*buffer;
  unsigned		length;
  unsigned		line;
  unsigned		column;
  unsigned		index;
  const char		*error;
} context;

static inline int
get(context *ctxt)
{
  if (ctxt->index < ctxt->length)
    {
      int	c = ctxt->buffer[ctxt->index++];

      ctxt->column++;
      if (c == '\n')
	{
	  ctxt->line++;
	  ctxt->column = 1;
	}
      return c;
    }
  return -1;
}

static inline int
skipSpace(context *ctxt)
{
  while (ctxt->index < ctxt->length && isspace(ctxt->buffer[ctxt->index]))
    {
      get(ctxt);
    }
  if (ctxt->index < ctxt->length)
    {
      return ctxt->buffer[ctxt->index];
    }
  return -1;
}

static id
parse(context *ctxt)
{
  int	c;

  skipSpace(ctxt);
  c = get(ctxt);
  if (c < 0)
    {
      return nil;
    }
  else if ('"' == c)
    {
      BOOL	escapes = NO;
      unsigned	start = ctxt->index;
      NSString	*s;

      while ((c = get(ctxt)) >= 0)
	{
	  if ('\\' == c)
	    {
	      escapes = YES;
	      c = get(ctxt);
	    }
	  else if ('"' == c)
	    {
	      break;
	    }
	  else if (c < 0)
	    {
	      ctxt->error = "premature end of string";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	}
      if (NO == escapes)
	{
	  s = [NSString alloc];
	  s = [s initWithBytes: ctxt->buffer + start
			length: ctxt->index - start - 1
		      encoding: NSUTF8StringEncoding];
	  [s autorelease];
	}
      else
	{
	  NSMutableString	*m;
	  NSRange		r;

	  m = [NSMutableString alloc];
	  m = [m initWithBytes: ctxt->buffer + start
			length: ctxt->index - start - 1
		      encoding: NSUTF8StringEncoding];
	  [m autorelease];
	  r = NSMakeRange(0, [m length]);
	  r = [m rangeOfString: @"\\" options: NSLiteralSearch range: r];
	  while (r.length > 0)
	    {
	      unsigned	pos = r.location;
	      NSString	*rep;

	      c = [m characterAtIndex: pos + 1];
	      if ('u' == c)
		{
		  const char	*hex;
		  unichar	u;

		  if (pos + 6 > [m length])
		    {
		      ctxt->error = "short unicode escape in string";
		      ctxt->index = ctxt->length;
		      return nil;
		    }
		  hex = [[m substringWithRange: NSMakeRange(pos + 2, 4)]
		    UTF8String];
		  if (isxdigit(hex[0]) && isxdigit(hex[1])
		    && isxdigit(hex[2]) && isxdigit(hex[3]))
		    {
		      u = (unichar) strtol(hex, 0, 16);
		    }
		  else
		    {
		      ctxt->error = "invalid unicode escape in string";
		      ctxt->index = ctxt->length;
		      return nil;
		    }
		  rep = [NSString stringWithCharacters: &u length: 1];
		}
	      else
		{
		  if ('"' == c) rep = @"\"";
		  else if ('\\' == c) rep = @"\\";
		  else if ('b' == c) rep = @"\b";
		  else if ('f' == c) rep = @"\f";
		  else if ('r' == c) rep = @"\r";
		  else if ('n' == c) rep = @"\n";
		  else if ('t' == c) rep = @"\t";
		  else rep = [NSString stringWithFormat: @"%c", (char)c];
		}
	      [m replaceCharactersInRange: r withString: rep];
	      pos++;
	      r = NSMakeRange(pos, [m length] - pos);
	      r = [m rangeOfString: @"\\" options: NSLiteralSearch range: r];
	    }
	  s = [[m copy] autorelease];
	}
      return s;
    }
  else if ('[' == c)
    {
      NSMutableArray	*a = [NSMutableArray array];

      for (;;)
	{
	  id	o;

	  if (nil != (o = parse(ctxt)))
	    {
	      [a addObject: o];
	    }

	  c = skipSpace(ctxt);
	  if (']' == c)
	    {
	      get(ctxt);
	      return a;
	    }

	  if (c != ',')
	    {
	      if (c < 0)
		{
		  ctxt->error = "premature end of array";
		}
	      else
		{
		  ctxt->error = "bad character in array";
		}
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  get(ctxt);	// Skip past comma
	}
    }
  else if ('{' == c)
    {
      NSMutableDictionary	*d = [NSMutableDictionary dictionary];

      for (;;)
	{
	  id	k;
	  id	v;

	  k = parse(ctxt);
	  c = skipSpace(ctxt);
	  if ('}' == c && nil == k)
	    {
	      get(ctxt);
	      return d;	// Empty
	    }
	  if (NO == [k isKindOfClass: [NSString class]])
	    {
	      ctxt->error = "non-string value for key";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  if (':' != c)
	    {
	      ctxt->error = "missing colon after key";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  get(ctxt);	// Skip the colon
	  v = parse(ctxt);
	  if (nil == v)
	    {
	      ctxt->error = "missing value after colon";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  c = skipSpace(ctxt);
	  if (',' == c)
	    {
	      [d setObject: v forKey: k];
	      get(ctxt);
	    }
	  else if ('}' == c)
	    {
	      [d setObject: v forKey: k];
	      get(ctxt);
	      return d;
	    }
	  else
	    {
	      if (c < 0)
		{
		  ctxt->error = "premature end of object";
		}
	      else
		{
		  ctxt->error = "bad character in object";
		}
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	}
    }
  else if ('-' == c || isdigit(c))
    {
      const char	*s = (const char*)ctxt->buffer + ctxt->index - 1;
      char		*e = 0;
      NSNumber		*n = nil;
      double		d;
      long long		l;
      unsigned		pos = ctxt->index;
      BOOL		tryFloat = NO;

      if ('-' == 'c') pos++;
      while (pos < ctxt->length && isdigit(ctxt->buffer[pos]))
	{
	  pos++;
	}
      if (pos < ctxt->length && '.' == ctxt->buffer[pos])
	{
	  tryFloat = YES;
	  pos++;
	  while (pos < ctxt->length && isdigit(ctxt->buffer[pos]))
	    {
	      pos++;
	    }
	}
      if (pos < ctxt->length
	&& ('e' == ctxt->buffer[pos] || 'E' == ctxt->buffer[pos]))
	{
	  tryFloat = YES;
	  pos++;
	  if (pos < ctxt->length
	    && ('+' == ctxt->buffer[pos] || '-' == ctxt->buffer[pos]))
	    {
	      pos++;
	    }
	  while (pos < ctxt->length && isdigit(ctxt->buffer[pos]))
	    {
	      pos++;
	    }
	}

      if (YES == tryFloat)
	{
	  d = strtod(s, &e);
	  if (e == s)
	    {
	      ctxt->error = "unparsable numeric value";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  n = [NSNumber numberWithDouble: d];
	}
      else
	{
	  l = strtoll(s, &e, 10);
	  if (e == s)
	    {
	      ctxt->error = "unparsable integer value";
	      ctxt->index = ctxt->length;
	      return nil;
	    }
	  n = [NSNumber numberWithLongLong: l];
	}
      if (nil == n)
	{
	  ctxt->error = "failed to parse numeric value";
	  ctxt->index = ctxt->length;
	  return nil;
	}

      /* Step past the numeric value.
       */
      while (ctxt->index < pos)
	{
	  get(ctxt);
	}
      return n;
    }
  else if ('t' == c)
    {
      if (get(ctxt) == 'r' && get(ctxt) == 'u' && get(ctxt) == 'e')
	{
	  return [NSNumber numberWithBool: YES];
	}
      ctxt->error = "bad character (expecting 'true')";
      ctxt->index = ctxt->length;
      return nil;
    }
  else if ('f' == c)
    {
      if (get(ctxt) == 'a' && get(ctxt) == 'l' && get(ctxt) == 's'
	&& get(ctxt) == 'e')
	{
	  return [NSNumber numberWithBool: NO];
	}
      ctxt->error = "bad character (expecting 'false')";
      ctxt->index = ctxt->length;
      return nil;
    }
  else if ('n' == c)
    {
      if (get(ctxt) == 'u' && get(ctxt) == 'l' && get(ctxt) == 'l')
	{
	  return [NSNull null];
	}
      ctxt->error = "bad character (expecting 'null')";
      ctxt->index = ctxt->length;
      return nil;
    }
  else
    {
      ctxt->index--;	// Push back character
      return nil;
    }
}

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
  id			v;

  [self reset];

  ms = [self mutableString];
  [ms setString: @""];

  if (nil != method)
    {
      v = [parameters objectForKey: method];
    }
  else if (nil != order)
    {
      unsigned	c = [order count];
      unsigned	i;

      v = [NSMutableArray arrayWithCapacity: c];
      for (i = 0; i < c; i++)
	{
	  NSString	*k = [order objectAtIndex: i];
	  id		o = [parameters objectForKey: k];

	  if (nil == o)
	    {
	      o = [NSNull null];
	    }
	  [v addObject: o];
	}
    }
  else
    {
      v = parameters;
    }
  [self _appendObject: v];
  return [ms dataUsingEncoding: NSUTF8StringEncoding];
}

- (NSData*) buildResponse: (NSString*)method
               parameters: (NSDictionary*)parameters
                    order: (NSArray*)order;
{
  return [self buildRequest: method parameters: parameters order: order];
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

  result = [NSMutableDictionary dictionaryWithCapacity: 3];

  [self reset];
  pool = [NSAutoreleasePool new];
  NS_DURING
    {
      context	x;
      id	o;

      x.buffer = (const unsigned char*)[data bytes];
      x.length = [data length];
      x.line = 1;
      x.column = 1;
      x.index = 0;

      o = parse(&x);
      if (skipSpace(&x) >= 0)
	{
	  x.error = "unexpected data at end of text";
	}

      params = [NSMutableDictionary dictionaryWithCapacity: 1];
      if (o == nil)
	{
	  [params setObject: [NSNull null] forKey: @"Result"];
	}
      else
	{
	  [params setObject: o forKey: @"Result"];
	}
      [result setObject: params forKey: GWSParametersKey];

      order = [NSMutableArray arrayWithCapacity: 1];
      [order addObject: @"Result"];
      [result setObject: order forKey: GWSOrderKey];
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

      if (c == '"' || c == '\\'
	|| c == '\b' || c == '\f' || c == '\n' || c == '\r' || c == '\t')
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

      if (c == '"' || c == '\\'
	|| c == '\b' || c == '\f' || c == '\n' || c == '\r' || c == '\t')
	{
	  to[j++] = '\\';
          switch (c)
	    {
	      case '\\': to[j++] = '\\'; break;
	      case '\b': to[j++] = 'b'; break;
	      case '\f': to[j++] = 'f'; break;
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


