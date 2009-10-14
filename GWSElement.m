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

@implementation GWSElement

static NSCharacterSet	*ws = nil;

+ (void) initialize
{
  ws = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
}

- (void) addContent: (NSString*)content
{
  if ([content length] > 0)
    {
      if (_content == nil)
        {
	  unsigned	length = [content length];
	  unsigned	pos = 0;

	  /* Ignore leading white space within an element.
	   */
	  while (pos < length
	    && [ws characterIsMember: [content characterAtIndex: pos]] == YES)
	    {
	      pos++;
	    }
	  if (pos > 0)
	    {
	      content = [content substringFromIndex: pos];
	    }
          _content = [content mutableCopy];
        }
      else
        {
          [_content appendString: content];
        }
    }
}

- (void) addChild: (GWSElement*)child
{
  [self insertChild: child atIndex: [_children count]];
}

- (GWSElement*) addChildNamed: (NSString*)name
		    namespace: (NSString*)namespace
		    qualified: (NSString*)qualified
		      content: (NSString*)content, ...
{
  va_list		ap;
  NSDictionary		*attributes = nil;
  NSMutableDictionary	*a = nil;
  GWSElement		*e;
  NSString		*k;
  
  va_start (ap, content);
  while ((k = va_arg(ap, NSString*)) != nil)
    {
      NSString *v;

      if (attributes == nil)
	{
	  /* As a special case, we are allowed to have a single NSDictionary
	   * rather than a nil terminated llist of keys and values.
	   */
	  if ([k isKindOfClass: [NSDictionary class]] == YES)
	    {
	      attributes = (NSDictionary*)k;
	      break;
	    }
	  a = [NSMutableDictionary new];
	  attributes = a;
	}
      v = va_arg(ap, NSString*);
      if (v == nil)
	{
	  [attributes release];
	  [NSException raise: NSInvalidArgumentException
		      format: @"attribute name/value pairs unbalanced"];
	}
      [a setObject: v forKey: k];
    }
  va_end (ap);
  e = [[GWSElement alloc] initWithName: name
			     namespace: namespace
			     qualified: qualified
			    attributes: attributes];
  if (content != nil)
    {
      [e addContent: content];
    }
  [self addChild: e];
  [e release];
  return e;
}

- (NSString*) attributeForName: (NSString*)name
{
  return [_attributes objectForKey: name];
}

- (NSDictionary*) attributes
{
  return [[_attributes copy] autorelease];
}

- (GWSElement*) childAtIndex: (unsigned)index
{
  return [_children objectAtIndex: index];
}

- (NSArray*) children
{
  return [[_children copy] autorelease];
}

- (NSString*) content
{
  if (_content == nil)
    {
      return @"";
    }
  else
    {
      unsigned	pos = [_content length];

      /* Strip trailing white space (leading space was already stripped as
       * content was added).
       */
      while (pos > 0
	&& [ws characterIsMember: [_content characterAtIndex: pos-1]] == YES)
	{
	  pos--;
	}
      return [_content substringToIndex: pos];
    }
}

- (unsigned) countChildren
{
  return [_children count];
}

- (void) dealloc
{
  [_attributes release];
  [_content release];
  [_children release];
  [_name release];
  [_namespace release];
  [_namespaces release];
  [_prefix release];
  [_qualified release];
  [_literal release];
  [_start release];
  [super dealloc];
}

- (NSString*) description
{
  return [[super description] stringByAppendingFormat: @" %@ %@",
    [self qualified], [self attributes]];
}

- (void) encodeContentWith: (GWSCoder*)coder
{
  if (_literal == nil)
    {
      unsigned  c = [_children count];

      if (c > 0)
        {
          unsigned      i;

          [coder indent];
          for (i = 0; i < c; i++)
            {
              [[_children objectAtIndex: i] encodeWith: coder];
            }
          [coder unindent];
          [coder nl];
        }
      else
        {
          [[coder mutableString]
	    appendString: [coder escapeXMLFrom: [self content]]];
        }
    }
}

- (void) encodeEndWith: (GWSCoder*)coder
{
  if (_literal == nil)
    {
      NSMutableString   *xml = [coder mutableString];

      [xml appendString: @"</"];
      [xml appendString: _qualified];
      [xml appendString: @">"];
    }
}

- (BOOL) encodeStartWith: (GWSCoder*)coder collapse: (BOOL)flag
{
  if (_literal == nil)
    {
      NSMutableString   *xml = [coder mutableString];

      if (_start == nil)
	{
	  unsigned	pos = [xml length];

	  [xml appendString: @"<"];
	  [xml appendString: _qualified];
	  if ([_attributes count] > 0)
	    {
	      NSEnumerator      *e = [_attributes keyEnumerator];
	      NSString          *k;

	      while ((k = [e nextObject]) != nil)
		{
		  NSString      *v = [_attributes objectForKey: k];

		  [xml appendString: @" "];
		  [xml appendString: [coder escapeXMLFrom: k]];
		  [xml appendString: @"=\""];
		  [xml appendString: [coder escapeXMLFrom: v]];
		  [xml appendString: @"\""];
		}
	    }
	  if ([_namespaces count] > 0)
	    {
	      NSEnumerator      *e = [_namespaces keyEnumerator];
	      NSString          *k;

	      while ((k = [e nextObject]) != nil)
		{
		  NSString      *v = [_namespaces objectForKey: k];

		  [xml appendString: @" "];
		  if ([k length] == 0)
		    {
		      [xml appendString: @"xmlns"];
		    }
		  else
		    {
		      [xml appendString: @"xmlns:"];
		      [xml appendString: [coder escapeXMLFrom: k]];
		    }
		  [xml appendString: @"=\""];
		  [xml appendString: [coder escapeXMLFrom: v]];
		  [xml appendString: @"\""];
		}
	    }
	  _start = [[xml substringFromIndex: pos] retain];
	}
      else
	{
	  // use cached version of start element
	  [xml appendString: _start];
	}
      if (flag == YES && [_content length] == 0 && [_children count] == 0)
        {
          [xml appendString: @" />"];       // Empty element.
          return YES;
        }
      [xml appendString: @">"];
      return NO;
    }
  return YES;
}

- (void) encodeWith: (GWSCoder*)coder
{
  [coder nl];
  if (_literal == nil)
    {
      if ([self encodeStartWith: coder collapse: YES] == NO)
        {
          [self encodeContentWith: coder];
          [self encodeEndWith: coder];
        }
    }
  else
    {
      [[coder mutableString] appendString: _literal];
    }
}

- (GWSElement*) findElement: (NSString*)name
{
  if ([_name isEqualToString: name] == YES)
    {
      return self;
    }
  else
    {
      GWSElement	*child = [self firstChild];

      while (child != nil)
	{
	  GWSElement	*found = [child findElement: name];

	  if (found != nil)
	    {
	      return found;
	    }
	  child = [child sibling];
	}
      return nil;
    }
}

- (GWSElement*) firstChild
{
  if ([_children count] == 0)
    {
      return nil;
    }
  return [_children objectAtIndex: 0];
}

- (unsigned) index
{
  if (_parent == nil)
    {
      return NSNotFound;
    }
  return [_parent->_children indexOfObjectIdenticalTo: self];
}

- (id) initWithName: (NSString*)name
          namespace: (NSString*)namespace
          qualified: (NSString*)qualified
         attributes: (NSDictionary*)attributes
{
  if ((self = [super init]) != nil)
    {
      NSZone    *z = [self zone];

      _name = [name copyWithZone: z];
      _namespace = [namespace copyWithZone: z];
      if (qualified == nil)
	{
	  _qualified = [_name retain];
	  _prefix = @"";
	}
      else
	{
	  NSRange	r = [qualified rangeOfString: @":"];

	  _qualified = [qualified copyWithZone: z];
	  if (r.length == 0)
	    {
	      _prefix = @"";
	    }
	  else
	    {
	      _prefix
		= [[qualified substringToIndex: r.location] copyWithZone: z];
	    }
	}
      if ([attributes count] > 0)
        {
          _attributes = [attributes mutableCopyWithZone: z];
        }
    }
  return self;
}

- (void) insertChild: (GWSElement*)child atIndex: (unsigned)index
{
  unsigned	count = [_children count];

  if (child->_parent == self)
    {
      unsigned  pos = [_children indexOfObjectIdenticalTo: child];

      if (index > count)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"index too large"];
	}
      if (index > pos)
	{
          [_children insertObject: child atIndex: index];
          [_children removeObjectAtIndex: pos];
	}
      else if (index < pos)
	{
          [_children insertObject: child atIndex: index];
          [_children removeObjectAtIndex: pos + 1];
	}
    }
  else
    {
      if (index > count)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"index too large"];
	}
      [child retain];
      [child remove];
      if (_children == nil)
        {
          _children = [[NSMutableArray alloc] initWithCapacity: 2];
        }
      [_children insertObject: child atIndex: index];
      child->_parent = self;
      [child release];
    }
}

- (id) mutableCopyWithZone: (NSZone*)aZone
{
  GWSElement    *copy;
  unsigned      count;
  unsigned      index;

  copy = [GWSElement allocWithZone: aZone];
  copy = [copy initWithName: _name
                  namespace: _namespace
                  qualified: _qualified
                 attributes: _attributes];
  copy->_content = [_content mutableCopyWithZone: aZone];
  copy->_namespaces = [_namespaces mutableCopyWithZone: aZone];
  count = [_children count];
  for (index = 0; index < count; index++)
    {
      GWSElement        *c;

      c = [[_children objectAtIndex: index] mutableCopyWithZone: aZone];
      [copy addChild: c];
      [c release];
    }
  return copy;
}

- (NSString*) name
{
  return _name;
}

- (NSString*) namespace
{
  return _namespace;
}

- (NSString*) namespaceForPrefix: (NSString*)prefix
{
  NSString	*ns;

  if (prefix == nil)
    {
      prefix = @"";
    }
  ns = [_namespaces objectForKey: prefix];
  if (ns == nil)
    {
      ns = [_parent namespaceForPrefix: prefix];
    }
  return ns;
}

- (NSDictionary*) namespaces
{
  return [[_namespaces copy] autorelease];
}

- (GWSElement*) parent
{
  return _parent;
}

- (NSMutableArray*) path
{
  NSMutableArray	*path;

  if (_parent == nil)
    {
      path = [NSMutableArray arrayWithCapacity: 10];
    }
  else
    {
      path = [_parent path];
    }
  [path addObject: [self name]];
  return path;
}

- (NSString*) prefix
{
  return _prefix;
}

- (NSString*) prefixForNamespace: (NSString*)uri
{
  GWSElement	*toSearch = self;

  if ([uri length] == 0)
    {
      return nil;
    }
  while (toSearch != nil)
    {
      NSDictionary	*d = [toSearch namespaces];
      NSEnumerator	*e = [d keyEnumerator];
      NSString		*k;

      while ((k = [e nextObject]) != nil)
	{
	  NSString	*v = [d objectForKey: k];

	  if ([uri isEqualToString: v] == YES)
	    {
	      /* Found the namespace ... but it's only usable if
	       * the corresponding previd maps to it at our level.
	       */
	      if ([uri isEqual: [self namespaceForPrefix: k]] == YES)
		{
		  return k;
		}
	    }
	}
      toSearch = [toSearch parent];
    }
  return nil;
}

- (NSString*) qualified
{
  return _qualified;
}
 
- (void) remove
{
  if (_parent != nil)
    {
      GWSElement    *p = _parent;

      _parent = nil;
      [p->_children removeObjectIdenticalTo: self];
      if ([p->_children count] == 0)
        {
          [p->_children release];
          p->_children = nil;
        }
    }
}

- (void) setAttribute: (NSString*)attribute forKey: (NSString*)key
{
  if (key == nil)
    {
      [_attributes release];
      _attributes = nil;
    }
  else if (attribute == nil)
    {
      if (_attributes != nil)
        {
          [_attributes removeObjectForKey: key];
          if ([_attributes count] == 0)
            {
              [_attributes release];
              _attributes = nil;
            }
        }
    }
  else
    {
      if (_attributes == nil)
        {
          _attributes = [[NSMutableDictionary alloc] initWithCapacity: 1];
        }
      [_attributes setObject: attribute forKey: key];
    }
  [_start release];	// Discard any cached start element
  _start = nil;
}

- (void) setContent: (NSString*)content
{
  if (_content != content)
    {
      [_content release];
      _content = nil;
      [self addContent: content];
    }
}

- (void) setLiteralValue: (NSString*)xml
{
  if (_literal != xml)
    {
      id        o = _literal;

      _literal = [xml retain];
      [o release];
    }
  [_start release];	// Discard any cached start element
  _start = nil;
}

- (void) setName: (NSString*)name
{
  NSAssert([_name length] > 0, NSInvalidArgumentException);
  name = [name copy];
  [_name release];
  _name = name;
  [_qualified release];
  if (_prefix == nil)
    {
      _qualified = [_name retain];
    }
  else
    {
      _qualified = [[NSString alloc] initWithFormat: @"%@:%@", _prefix, _name];
    }
  [_start release];	// Discard any cached start element
  _start = nil;
}

- (void) setNamespace: (NSString*)uri forPrefix: (NSString*)prefix
{
  if (prefix == nil)
    {
      prefix = @"";
    }
  if ([uri length] == 0)
    {
      if (_namespaces != nil)
        {
          [_namespaces removeObjectForKey: prefix];
          if ([_namespaces count] == 0)
            {
              [_namespaces release];
              _namespaces = nil;
            }
        }
    }
  else
    {
      if (_namespaces == nil)
        {
          _namespaces = [[NSMutableDictionary alloc] initWithCapacity: 1];
        }
      uri = [uri copy];
      [_namespaces setObject: uri forKey: prefix];
      [uri release];
    }
  if ([prefix isEqual: [self prefix]])
    {
      [_namespace release];
      _namespace = [uri copy];
    }
  [_start release];	// Discard any cached start element
  _start = nil;
}

- (void) setPrefix: (NSString*)prefix
{
  NSString	*ns;

  if (prefix == nil)
    {
      prefix = @"";
    }
  ns = [self namespaceForPrefix: prefix];
  if (ns == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"No namespace found for prefix '%@'", prefix];
    }
  else
    {
      NSRange	r = [_qualified rangeOfString: @":"];

      if ([prefix length] == 0)
	{
	  if (r.length > 0)
	    {
	      NSString	*tmp = [_qualified substringFromIndex: NSMaxRange(r)];

	      [_qualified release];
	      _qualified = [tmp retain];
	      [ns retain];
	      [_namespace release];
	      _namespace = ns;
	    }
	}
      else
	{
	  if (r.length != [prefix length]
	    || [prefix isEqual: [self prefix]] == NO)
	    {
	      NSString	*tmp;

	      if (r.length > 0)
		{
		  tmp = [_qualified substringFromIndex: NSMaxRange(r)];
		}
	      else
		{
		  tmp = _qualified;
		}
	      tmp = [prefix stringByAppendingFormat: @":%@", tmp];
	      [_qualified release];
	      _qualified = [tmp retain];
	      [ns retain];
	      [_namespace release];
	      _namespace = ns;
	    }
	}
    }
  [_prefix release];
  _prefix = [prefix copy];
  [_start release];	// Discard any cached start element
  _start = nil;
}

- (GWSElement*) sibling
{
  unsigned      index = [self index];

  if (index == NSNotFound || (index + 1) >= [_parent countChildren])
    {
      return nil;
    }
  return [_parent childAtIndex: index + 1];
}

@end

