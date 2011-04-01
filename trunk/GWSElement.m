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
static SEL 		cimSel = 0;
static BOOL		(*cimImp)(id, SEL, unichar) = 0;
static Class		GWSElementClass = Nil;

+ (void) initialize
{
  if ([GWSElement class] == self)
    {
      GWSElementClass = self;
      ws = [[NSCharacterSet whitespaceAndNewlineCharacterSet] retain];
      cimSel = @selector(characterIsMember:);
      cimImp = (BOOL(*)(id,SEL,unichar))[ws methodForSelector: cimSel]; 
    }
}

#define	MEMBER(X)	(*cimImp)(ws, cimSel, (X))

- (void) addContent: (NSString*)content
{
  NSUInteger	length = [content length];

  if (length > 0)
    {
      if (_content == nil)
        {
	  NSUInteger	pos = 0;

	  /* Ignore leading white space within an element.
	   */
	  while (pos < length && MEMBER([content characterAtIndex: pos]))
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
  if (NO == [child isKindOfClass: GWSElementClass])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"-addChild: child is not a GWSElement"];
    }
  if (YES == [child isAncestorOf: self])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"-addChild: child is ancestor"];
    }
  [child retain];
  [child remove];
  if (nil == _first)
    {
      _first = child;
    }
  else
    {
      child->_next = _first;
      child->_prev = _first->_prev;
      _first->_prev = child;
      child->_prev->_next = child;
    }
  child->_parent = self;
  _children++;
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
  [attributes release];
  if (content != nil)
    {
      [e addContent: content];
    }
  if (nil == _first)
    {
      _first = e;
    }
  else
    {
      e->_next = _first;
      e->_prev = _first->_prev;
      e->_next->_prev = e;
      e->_prev->_next = e;
    }
  e->_parent = self;
  _children++;
  return e;
}

- (NSString*) attributeForName: (NSString*)name
{
  return [_attributes objectForKey: name];
}

- (NSDictionary*) attributes
{
  if (_attributes == nil)
    {
      static NSDictionary	*empty = nil;

      if (empty == nil)
	{
	  empty = [NSDictionary new];
	}
      return empty;
    }
  return [[_attributes copy] autorelease];
}

- (GWSElement*) childAtIndex: (NSUInteger)index
{
  if (index >= _children)
    {
      [NSException raise: NSRangeException
		  format: @"-childAtIndex: index out of range"];
      return nil;
    }
  else
    {
      GWSElement	*tmp = _first;

      while (index-- > 0)
	{
	  tmp = tmp->_next;
	}
      return tmp;
    }
}

- (NSArray*) children
{
  if (0 == _children)
    {
      static NSArray	*empty = nil;

      if (empty == nil)
	{
	  empty = [NSArray new];
	}
      return empty;
    }
  else
    {
      NSMutableArray	*m = [NSMutableArray arrayWithCapacity: _children];
      NSUInteger	counter = _children;
      GWSElement	*tmp = _first;

      while (counter-- > 0)
	{
	  [m addObject: tmp];
	  tmp = tmp->_next;
	}
      return m;
    }
}

- (NSString*) content
{
  if (_content == nil)
    {
      return @"";
    }
  else
    {
      NSUInteger	pos = [_content length];

      /* Strip trailing white space (leading space was already stripped as
       * content was added).
       */
      while (pos > 0 && MEMBER([_content characterAtIndex: pos-1]))
	{
	  pos--;
	}
      return [_content substringToIndex: pos];
    }
}

- (NSUInteger) countChildren
{
  return _children;
}

- (void) dealloc
{
  [_attributes release];
  [_content release];
  while (nil != _first)
    {
      [_first remove];
    }
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
      if (_children > 0)
        {
          NSUInteger	count = _children;
	  GWSElement	*tmp = _first;

          [coder indent];
          while (count-- > 0)
            {
              [tmp encodeWith: coder];
	      tmp = tmp->_next;
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
	  NSUInteger	pos = [xml length];

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
      if (flag == YES && [_content length] == 0 && _children == 0)
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
      GWSElement	*child = _first;
      NSUInteger	count = _children;

      while (count-- > 0)
	{
	  GWSElement	*found = [child findElement: name];

	  if (found != nil)
	    {
	      return found;
	    }
	  child = child->_next;
	}
      return nil;
    }
}

- (GWSElement*) firstChild
{
  return _first;
}

- (NSUInteger) index
{
  if (nil != _parent)
    {
      NSUInteger	i = 0;
      NSUInteger	c = _parent->_children;
      GWSElement	*tmp = _parent->_first;

      while (c-- > 0)
	{
	  if (tmp == self)
	    {
	      return i;
	    }
	  i++;
	  tmp = tmp->_next;
	}
    }
  return NSNotFound;
}

- (id) initWithName: (NSString*)name
          namespace: (NSString*)namespace
          qualified: (NSString*)qualified
         attributes: (NSDictionary*)attributes
{
  if ((self = [super init]) != nil)
    {
      NSZone    *z = [self zone];

      _next = _prev = self;
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

- (void) insertChild: (GWSElement*)child atIndex: (NSUInteger)index
{
  if (index > _children)
    {
      [NSException raise: NSRangeException
		  format: @"-insertChild:atIndex: index out of range"];
    }
  else if (NO == [child isKindOfClass: GWSElementClass])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"-insertChild:atIndex: child is not a GWSElement"];
    }
  else if (child->_parent == self)
    {
      /* The child is being moved within the list (unless it's the only one)
       */
      if (_children > 1)
	{
	  GWSElement	*tmp;

	  /* Adjust the start of the list if the child was the first element.
	   */
	  if (_first == child)
	    {
	      _first = child->_next;
	    }

	  /* Remove the child from its current position.
	   */
	  child->_next->_prev = child->_prev; 
	  child->_prev->_next = child->_next; 

	  /* Determine insertion point.
	   */
	  tmp = _first;
	  if (0 == index)
	    {
	      _first = child;			// Child will be first in list
	    }
	  else if (index != _children)
	    {
	      while (--index > 0)
		{
		  tmp = tmp->_next;
		}
	    }

	  /* Insert the child.
	   */
	  child->_next = tmp;
	  child->_prev = tmp->_prev;
	  child->_next->_prev = child;
	  child->_prev->_next = child;
	}
    }
  else if (YES == [child isAncestorOf: self])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"-insertChild:atIndex: child is ancestor"];
    }
  else
    {
      [child retain];
      [child remove];
      if (nil == _first)
        {
          _first = child;
        }
      else
	{
	  GWSElement	*tmp;

	  tmp = _first;
	  if (0 == index)
	    {
	      _first = child;	// New start of children
	    }
	  else if (index != _children)
	    {
	      while (--index > 0)
		{
		  tmp = tmp->_next;
		}
	    }
	  child->_next = tmp;
	  child->_prev = tmp->_prev;
	  child->_next->_prev = child;
	  child->_prev->_next = child;
	}
      child->_parent = self;
      _children++;
    }
}

- (BOOL) isAncestorOf: (GWSElement*)other
{
  if (YES == [other isKindOfClass: GWSElementClass])
    {
      GWSElement	*elem = other->_parent;

      while (elem != nil)
	{
	  if (elem == self)
	    {
	      return YES;
	    }
	  elem = elem->_parent;
        }
    }
  return NO;
}

- (BOOL) isDescendantOf: (GWSElement*)other
{
  if (YES == [other isKindOfClass: GWSElementClass])
    {
      GWSElement	*elem = _parent;

      while (elem != nil)
	{
	  if (elem == other)
	    {
	      return YES;
	    }
	  elem = elem->_parent;
	}
    }
  return NO;
}

- (BOOL) isNamed: (NSString*)aName
{
  return [_name isEqualToString: aName];
}

- (BOOL) isSiblingOf: (GWSElement*)other
{
  if (YES == [other isKindOfClass: GWSElementClass])
    {
      if (_parent != nil && other->_parent == _parent)
	{
	  return YES;
	}
    }
  return NO;
}

- (GWSElement*) lastChild
{
  if (nil == _first)
    {
      return nil;
    }
  return _first->_prev;
}

- (id) mutableCopyWithZone: (NSZone*)aZone
{
  GWSElement    *copy;

  copy = [GWSElement allocWithZone: aZone];
  copy = [copy initWithName: _name
                  namespace: _namespace
                  qualified: _qualified
                 attributes: _attributes];
  copy->_content = [_content mutableCopyWithZone: aZone];
  copy->_namespaces = [_namespaces mutableCopyWithZone: aZone];
  if (_children > 0)
    {
      NSUInteger	count = _children - 1;
      GWSElement	*from = _first;
      GWSElement	*first = [from mutableCopyWithZone: aZone];
      
      while (count-- > 0)
	{
	  GWSElement        *c;

	  from = from->_next;
	  c = [from mutableCopyWithZone: aZone];
	  c->_parent = copy;
	  c->_next = first;
	  c->_prev = first->_prev;
	  c->_next->_prev = c;
	  c->_prev->_next = c;
	}
      copy->_first = first;
      copy->_children = _children;
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
  if (_namespaces == nil)
    {
      static NSDictionary	*empty = nil;

      if (empty == nil)
	{
	  empty = [NSDictionary new];
	}
      return empty;
    }
  return [[_namespaces copy] autorelease];
}

- (GWSElement*) nextElement: (NSString*)name
{
  NSUInteger	count = _children;
  GWSElement	*elem = _first;
  GWSElement	*up;

  while (count-- > 0)
    {
      GWSElement	*found = [elem findElement: name];

      if (found != nil)
	{
	  return found;
	}
      elem = elem->_next;
    }
  elem = [self sibling];
  while (elem != nil)
    {
      GWSElement	*found = [elem findElement: name];

      if (found != nil)
	{
	  return found;
	}
      elem = [elem sibling];
    }
  up = _parent;
  while (up != nil)
    {
      elem = [up sibling];
      while (elem != nil)
	{
	  GWSElement	*found = [elem findElement: name];

	  if (found != nil)
	    {
	      return found;
	    }
	  elem = [elem sibling];
	}
      up = [up parent];
    }
  return nil;
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
      toSearch = toSearch->_parent;
    }
  return nil;
}

- (GWSElement*) previous
{
  if (self == _first)
    {
      return nil;
    }
  return _prev;
}

- (NSString*) qualified
{
  return _qualified;
}
 
- (void) remove
{
  if (_parent != nil)
    {
      _parent->_children--;
      if (0 == _parent->_children)
	{
	  _parent->_first = nil;
	}
      else
	{
	  _next->_prev = _prev;
	  _prev->_next = _next;
	  if (_parent->_first == self)
	    {
	      _parent->_first = _next;
	    }
	}
      _parent = nil;
      _next = _prev = self;
      [self release];
    }
}

- (void) setAttribute: (NSString*)attribute forKey: (NSString*)key
{
  if (key == nil)
    {
      [_attributes removeAllObjects];
    }
  else if (attribute == nil)
    {
      if (_attributes != nil)
        {
          [_attributes removeObjectForKey: key];
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
  if ([_prefix length] == 0)
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
  if (nil == _parent)
    {
      return nil;
    }
  else
    {
      GWSElement	*sib = _next;

      if (sib == _parent->_first)
	{
	  return nil;	// We are the last child
	}
      return sib;
    }
}

@end
