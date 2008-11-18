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

@implementation	GWSService (Private)
- (void) _completed
{
  if (_input != nil)
    {
      [_input release];
      _input = nil;
    }
  if (_output != nil)
    {
      [_output release];
      _output = nil;
    }
  if ([_delegate respondsToSelector: @selector(completedRPC:)])
    {
      [_delegate completedRPC: self];
    }    
}

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
          NSString      *binding;

          name = [[elem attributes] objectForKey: @"name"];
          binding = [[elem attributes] objectForKey: @"binding"];
          if (name == nil)
            {
              NSLog(@"Port without a name in WSDL!");
            }
          else if ([_document portTypeWithName: name create: NO] == nil)
	    {
              NSLog(@"Port type '%@' in service but not in ports", name);
	    }
          else if (binding == nil)
            {
              NSLog(@"Port named '%@' without a binding in WSDL!", name);
            }
          else if ([_document bindingWithName: binding create: NO] == nil)
	    {
              NSLog(@"Port named '%@' with binding '%@' in service but "
		@"not in bindings", name, binding);
	    }
	  else
            {
              GWSPort	*port;

              port = [[GWSPort alloc] _initWithName: name
					   document: _document];
              if (_ports == nil)
                {
                  _ports = [NSMutableDictionary new];
                }
              if (port != nil)
                {
                  [_ports setObject: port forKey: [port name]];
                  [port release];
                }
              used = elem;
            }
          elem = [elem sibling];
          [used remove];
        }
      while (elem != nil)
        {
	  NSString	*problem;

	  problem = [_document _validate: elem in: @"port"];
	  if (problem != nil)
	    {
	      NSLog(@"Bad port extensibility: % @", problem);
	    }
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
  [_SOAPAction release];
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

- (GWSElement*) input
{
  return _input;
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

- (GWSElement*) output
{
  return _output;
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
  GWSElement		*ip = nil;
  GWSElement		*op = nil;

  if (_input != nil || _output != nil)
    {
      [self _setProblem: @"Earlier operation still in progress"];
      return NO;
    }

  /* If this is not a standalone service, we must set up information from
   * the parsed WSDL document.  Otherwise we just use whatever has been
   * set via the API.
   */
  if (_document != nil)
    {
      NSRange		r;
      NSString		*portName;
      NSString		*operationName;
      NSEnumerator	*enumerator;
      GWSElement	*elem;
      GWSPort		*port;
      GWSPortType	*portType;
      GWSBinding	*binding;
      GWSElement	*operation;

      r = [method rangeOfString: @"."];
      if (r.length == 1)
	{
	  portName = [method substringToIndex: r.location];
	  operationName = [method substringFromIndex: NSMaxRange(r)];
	}
      else
	{
	  portName = nil;
	  operationName = method;
	}

      /* Look through the ports declared in this service for one matching
       * the port name and operation name.  Get details by looking up
       * bindings, since we can't actually use a port/operation if there
       * is no binding for it.
       */
      enumerator = [_ports objectEnumerator];
      while ((port = [enumerator nextObject]) != nil)
	{
	  binding = [port binding];
	  portType = [binding type];
	  if (portType != nil)
	    {
	      operation = [[portType operations] objectForKey: operationName];
	      if (operation != nil)
		{
		  if (portName == nil || [portName isEqual: [portType name]])
		    {
		      break;	// matched
		    }
		  operation = nil;
		}
	    }
	}

      if (port == nil)
	{
	  [self _setProblem: [NSString stringWithFormat:
	    @"Unable to find port.operation matching '%@'", method]];
	  return NO;
	}
      else
	{
	  NSString	*problem;

	  /* Handle extensibility for port ...
	   * With SOAP this supplies the URL that we should send to.
	   */
          enumerator = [[port extensibility] objectEnumerator];
	  while ((elem = [enumerator nextObject]) != nil)
	    {
	      problem = [_document _setupService: self
					    from: elem
					      in: @"port"];
	      if (problem != nil)
		{
		  [self _setProblem: problem];
		  return NO;
		}
	    }

	  /* Handle SOAP binding ... this supplies the encoding style and
	   * transport that we should used.
	   */
          enumerator = [[binding extensibility] objectEnumerator];
	  while ((elem = [enumerator nextObject]) != nil)
	    {
	      problem = [_document _setupService: self
					    from: elem
					      in: @"binding"];
	      if (problem != nil)
		{
		  [self _setProblem: problem];
		  return NO;
		}
	    }

	  /* Now look at operation specific information.
	   */
	  elem = [operation firstChild];
	  while (elem != nil
	    && [[elem name] isEqualToString: @"input"] == NO
	    && [[elem name] isEqualToString: @"output"] == NO)
	    {
	      problem = [_document _setupService: self
					    from: elem
					      in: @"operation"];
	      if (problem != nil)
		{
		  [self _setProblem: problem];
		  return NO;
		}
	      elem = [elem sibling];
	    }

	  /* Now get (and make a note of) the input and output messages.
 	   */
	  if ([[elem name] isEqualToString: @"input"])
	    {
	      ip = elem;
	      elem = [elem sibling];
	    }
	  if ([[elem name] isEqualToString: @"output"])
	    {
	      op = elem;
	    }

	  /* Perform any extensibility setup for the input message.
	   */
	  for (elem = [_input firstChild]; elem != nil; elem = [elem sibling])
	    {
	      problem = [_document _setupService: self
					    from: elem
					      in: @"input"];
	      if (problem != nil)
		{
		  [self _setProblem: problem];
		  return NO;
		}
	    }
	}
    }

  if (_coder == nil)
    {
      [self _setProblem: @"no coder set  (use -setCoder:)"];
      return NO;
    }
  if (_connectionURL == nil)
    {
      [self _setProblem: @"no URL string set  (use -setURL:)"];
      return NO;
    }

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
  [request setValue: @"GWSService/0.1.0" forHTTPHeaderField: @"User-Agent"];
  [request setValue: @"text/xml" forHTTPHeaderField: @"Content-Type"];
  if (_SOAPAction != nil)
    {
      [request setValue: _SOAPAction forHTTPHeaderField: @"SOAPAction"];
    }
  [request setHTTPBody: data];

  /* Record information about the messages in progess.
   */
  _input = [ip retain];
  _output = [ip retain];

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

      _coder = nil;
      [old setService: nil];
      _coder = [aCoder retain];
      [old release];
      [_coder setService: self];
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

- (void) setSOAPAction: (NSString*)action
{
  if (_SOAPAction != action)
    {
      NSString	*old = _SOAPAction;

      _SOAPAction = [action copy];
      [old release];
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

- (void) setURL: (id)url
{
  [self setURL: url certificate: nil privateKey: nil password: nil];
}

- (void) setURL: (id)url
    certificate: (NSString*)cert
     privateKey: (NSString*)pKey
       password: (NSString*)pwd
{
  id	old;

  if ([url isKindOfClass: [NSURL class]])
    {
      url = [(NSURL*)url absoluteString];
    }
  if (url != nil)
    {
      NSURL	*u = [NSURL URLWithString: url];

      if (u == nil)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Bad URL (%@) supplied", url];
	}
    }
  old = _connectionURL;
  _connectionURL = [url copy];
  [old release];
  [_connection release];
  _connection = nil;
  [_response release];
  _response = [[NSMutableData alloc] init];
}

- (void) timeout: (NSTimer*)t
{
  [_timer invalidate];
  _timer = nil;
  [self _setProblem: @"timed out"];
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
  GWSPort	*port;
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
  while ((port = [enumerator nextObject]) != nil)
    {
      [tree addChild: [port tree]];
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
  [self _completed];
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
  [self _completed];
}

@end

@implementation	GWSService (Delegate)
- (void) completedRPC: (GWSService*)sender
{
}
@end
