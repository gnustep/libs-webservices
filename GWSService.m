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

#include <Foundation/Foundation.h>
#include "GWSPrivate.h"

@implementation	GWSService (Private)
- (id) _initWithName: (NSString*)name document: (GWSDocument*)document
{
  if ((self = [super init]) != nil)
    {
      GWSElement        *elem;

      _name = [name copy];
      _document = document;
      elem = [_document initializing];
      elem = [elem firstChild];
      if ([[elem name] isEqualToString: @"documentation"] == YES)
        {
          _documentation = [elem retain];
          elem = [elem sibling];
          [_documentation remove];
        }
      while (elem != nil && [[elem name] isEqualToString: @"port"] == YES)
        {
          GWSElement    *used = nil;
          NSString      *name;

          name = [[elem attributes] objectForKey: @"name"];
          if (name == nil)
            {
              NSLog(@"Port without a name in WSDL!");
            }
          else
            {
              if (_ports == nil)
                {
                  _ports = [NSMutableDictionary new];
                }
              used = elem;
              [_ports setObject: elem forKey: name];
            }
          elem = [elem sibling];
          [used remove];
        }
      while (elem != nil)
        {
          if (_extensibility == nil)
            {
              _extensibility = [NSMutableArray new];
            }
          [_extensibility addObject: elem];
          elem = [elem sibling];
          [[_extensibility lastObject] remove];
        }
    }
  return self;
}
- (void) _remove
{
  _document = nil;
}
- (void) _setProblem: (NSString*)s
{
  [_result release];
  _result = [[NSMutableDictionary alloc] initWithObjects: &s
						 forKeys: &GWSErrorKey
						   count: 1];
}

@end

@implementation	GWSService

- (GWSCoder*) coder
{
  return _coder;
}

- (BOOL) compact
{
  return _compact;
}

- (void) dealloc
{
  [_coder release];
  _coder = nil;
  [_tz release];
  if (_timer != nil)
    {
      [self timeout: nil];	// Treat as immediate timeout.
    }
  [_result release];
  if (_connection)
    {
      [_connection release];
    }
  [_response release];
  [_connectionURL release];
  [_documentation release];
  [_extensibility release];
  [_ports release];
  [_name release];
  [super dealloc];
}

- (id) delegate
{
  return _delegate;
}

- (GWSElement*) documentation
{
  return _documentation;
}

- (id) init
{
  return [self _initWithName: nil document: nil];
}

- (NSMutableDictionary*) invokeMethod: (NSString*)method 
                           parameters: (NSDictionary*)parameters
                                order: (NSArray*)order
                              timeout: (int)seconds
{
  NS_DURING
    {
      if ([self sendRequest: method
                 parameters: parameters
                      order: order
                    timeout: seconds] == YES)
	{
	  NSDate	*when = [[[_timer fireDate] retain] autorelease];

	  while (_timer != nil)
	    {
	      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
				       beforeDate: when];
	    }
	}
    }
  NS_HANDLER
    {
      [self _setProblem: [localException description]];
    }
  NS_ENDHANDLER

  return _result;  
}

- (NSString*) name
{
  return _name;
}

- (NSMutableDictionary*) result
{
  if (_timer == nil)
    {
      return _result;
    }
  else
    {
      return nil;
    }
}

- (BOOL) sendRequest: (NSString*)method 
          parameters: (NSDictionary*)parameters
               order: (NSArray*)order
             timeout: (int)seconds
{
  NSMutableURLRequest   *request;
  NSData	        *data;

  [self _setProblem: @"unable to send"];

  if (_timer != nil)
    {
      return NO;	// Send already in progress.
    }
  data = [_coder buildRequest: method parameters: parameters order: order];
  if (data == nil)
    {
      return NO;
    }

  _timer = [NSTimer scheduledTimerWithTimeInterval: seconds
					    target: self
					  selector: @selector(timeout:)
					  userInfo: nil
					   repeats: NO];

  request = [NSMutableURLRequest alloc];
  request = [request initWithURL: [NSURL URLWithString: _connectionURL]];
  [request setCachePolicy: NSURLRequestReloadIgnoringCacheData];
  [request setHTTPMethod: @"POST"];  
  [request setValue: @"GWSCoders/0.1.0" forHTTPHeaderField: @"User-Agent"];
  [request setValue: @"text/xml" forHTTPHeaderField: @"Content-Type"];
  [request setHTTPBody: data];

  _connection = [NSURLConnection alloc];
  _connection = [_connection initWithRequest: request delegate: self];
  [request release];
  return YES;
}

- (void) setCoder: (GWSCoder*)aCoder
{
  if (aCoder != _coder)
    {
      GWSCoder   *old = _coder;

      _coder = [aCoder retain];
      [old release];
    }
}

- (void) setCompact: (BOOL)flag
{
  _compact = flag;
}

- (void) setDelegate: (id)aDelegate
{
  _delegate = aDelegate;
}

- (void) setDocumentation: (GWSElement*)documentation
{
  if (documentation != _documentation)
    {
      id        o = _documentation;

      _documentation = [documentation retain];
      [o release];
      [_documentation remove];
    }
}

- (void) setTimeZone: (NSTimeZone*)timeZone
{
  if (_tz != timeZone)
    {
      NSTimeZone        *old = _tz;

      _tz = [timeZone retain];
      [old release];
    }
}

- (void) setURL: (NSString*)url
{
  [self setURL: url certificate: nil privateKey: nil password: nil];
}

- (void) setURL: (NSString*)url
    certificate: (NSString*)cert
     privateKey: (NSString*)pKey
       password: (NSString*)pwd
{
  if (url != nil)
    {
      _connectionURL = [url copy];
      _connection = nil;
      _response = [[NSMutableData alloc] init];
    }
}

- (void) timeout: (NSTimer*)t
{
  [_timer invalidate];
  _timer = nil;
  [_connection cancel];
}

- (NSTimeZone*) timeZone
{
  if (_tz == nil)
    {
      _tz = [[NSTimeZone timeZoneForSecondsFromGMT: 0] retain];
    }
  return _tz;
}

- (GWSElement*) tree
{
  GWSElement    *tree;
  GWSElement    *elem;
  NSEnumerator  *enumerator;
  NSString	*q;

  q = (_document == nil) ? (id)@"service" : (id)[_document qualify: @"service"];
  tree = [[GWSElement alloc] initWithName: @"service"
                                namespace: nil
                                qualified: q
                               attributes: nil];
  [tree setAttribute: _name forKey: @"name"];
  if (_documentation != nil)
    {
      elem = [_documentation mutableCopy];
      [tree addChild: elem];
      [elem release];
    }
  enumerator = [_ports objectEnumerator];
  while ((elem = [enumerator nextObject]) != nil)
    {
      elem = [elem mutableCopy];
      [tree addChild: elem];
      [elem release];
    }
  enumerator = [_extensibility objectEnumerator];
  while ((elem = [enumerator nextObject]) != nil)
    {
      elem = [elem mutableCopy];
      [tree addChild: elem];
      [elem release];
    }
  return [tree autorelease];
}

- (void) connection: (NSURLConnection*)connection
didCancelAuthenticationChallenge: (NSURLAuthenticationChallenge*)challenge
{
  /* DO NOTHING */
}

- (void) connection: (NSURLConnection*)connection
   didFailWithError: (NSError*)error
{
  [self _setProblem: [error localizedDescription]];
  [_timer invalidate];
  _timer = nil;
  if ([_delegate respondsToSelector: @selector(completedRPC:)])
    {
      [_delegate completedRPC: self];
    }    
}

- (void) connection: (NSURLConnection*)connection
didReceiveAuthenticationChallenge: (NSURLAuthenticationChallenge*)challenge 
{
}

- (void) connection: (NSURLConnection*)connection didReceiveData: (NSData*)data 
{
  [_response appendData: data];
}

- (void) connection: (NSURLConnection*)connection
 didReceiveResponse: (NSURLResponse*)response 
{
  /* DO NOTHING */
}

- (NSCachedURLResponse*) connection: (NSURLConnection*)connection
		  willCacheResponse: (NSCachedURLResponse*)cachedResponse
{
  return nil;
}

- (NSURLRequest*) connection: (NSURLConnection*)connection
	     willSendRequest: (NSURLRequest*)request
	    redirectResponse: (NSURLResponse*)redirectResponse 
{
  return nil;
}

- (void) connectionDidFinishLoading: (NSURLConnection*)connection 
{
  if (_result != nil)
    {
      [_result release];
      _result = nil;
    }
  NS_DURING
    {
      _result = [_coder parseMessage: _response];
    }
  NS_HANDLER
    {
      id        reason = [localException reason];

      _result = [NSMutableDictionary dictionaryWithObjects: &reason
						   forKeys: &GWSFaultKey
						     count: 1];
    }
  NS_ENDHANDLER
  if ([_response length] > 0)
    {
      [_result setObject: _response forKey: GWSResponseDataKey];
    }
  [_result retain];

  [_timer invalidate];
  _timer = nil;
    
  if ([_delegate respondsToSelector: @selector(completedRPC:)])
    {
      [_delegate completedRPC: self];
    }        
}


@end

@implementation	GWSService (Delegate)
- (void) completedRPC: (GWSService*)sender
{
}
@end
