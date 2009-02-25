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

/* To support client side SSL certificate authentication we use the old
 * NSURLHandle stuff with GNUstep extensions.  We use the _connection
 * ivar to hold the handle in this case.
 */
#define	handle	((NSURLHandle*)_connection)

@implementation	GWSService (Private)
- (void) _clean
{
  if (_operation != nil)
    {
      [_operation release];
      _operation = nil;
    }
  if (_parameters != nil)
    {
      [_parameters release];
      _parameters = nil;
    }
  if (_port != nil)
    {
      [_port release];
      _port = nil;
    }
  if (_request != nil)
    {
      [_request release];
      _request = nil;
    }
}

- (void) _completed
{
  if ([self debug] == YES)
    {
      if (_request != nil)
	{
	  [_result setObject: _request forKey: GWSRequestDataKey];
	}
      if (_response != nil)
	{
	  [_result setObject: _response forKey: GWSResponseDataKey];
	}
    }
  [self _clean];
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

      _SOAPAction = @"\"\"";
      _debug = [[NSUserDefaults standardUserDefaults] boolForKey: @"GWSDebug"];
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
					   document: _document
					       from: elem];
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

	  problem = [_document _validate: elem in: self];
	  if (problem != nil)
	    {
	      NSLog(@"Bad service extensibility: % @", problem);
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
  if (_result == nil)
    {
      _result = [NSMutableDictionary new];
    }
  [_result setObject: s forKey: GWSErrorKey];
}

- (NSString*) _setupFrom: (GWSElement*)element in: (id)section
{
  NSString	*n;

  n = [element namespace];
  if ([n length] == 0)
    {
      /* No namespace recorded directly in the element ... 
       * See if the document has a namespace for the element's prefix.
       */
      n = [element prefix];
      if (n == nil)
	{
	  n = @"";
	}
      n = [_document namespaceForPrefix: n];
    }
  if (n != nil)
    {
      GWSExtensibility	*e = [_document extensibilityForNamespace: n];

      if (e != nil)
	{
	  return [e validate: element for: _document in: section setup: self];
	}
    }
  return nil;
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
  [self _clean];
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

- (BOOL) debug
{
  return _debug;
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
  if (_operation != nil)
    {
      [self _setProblem: @"Earlier operation still in progress"];
      return NO;
    }

  /* Take a mutable copy of the parameters so that we can add keys to it
   * to control encoding options.
   */
  _parameters = [parameters mutableCopy];
  if (order != nil)
    {
      /* Store the ordering so that extensions can find it.
       */
      [_parameters setObject: order forKey: GWSOrderKey];
    }

  /* If this is not a standalone service, we must set up information from
   * the parsed WSDL document.  Otherwise we just use whatever has been
   * set via the API.
   */
  if (_document != nil)
    {
      NSRange		r;
      NSString		*portName;
      NSEnumerator	*enumerator;
      GWSElement	*elem;
      GWSPortType	*portType;
      GWSBinding	*binding;
      GWSElement	*operation;

      r = [method rangeOfString: @"."];
      if (r.length == 1)
	{
	  portName = [method substringToIndex: r.location];
	  _operation = [method substringFromIndex: NSMaxRange(r)];
	}
      else
	{
	  portName = nil;
	  _operation = method;
	}
      [_operation retain];

      /* Look through the ports declared in this service for one matching
       * the port name and operation name.  Get details by looking up
       * bindings, since we can't actually use a port/operation if there
       * is no binding for it.
       */
      enumerator = [_ports objectEnumerator];
      while ((_port = [enumerator nextObject]) != nil)
	{
	  binding = [_port binding];
	  portType = [binding type];
	  if (portType != nil)
	    {
	      operation = [[portType operations] objectForKey: _operation];
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
      [_port retain];

      if (_port == nil)
	{
	  [self _clean];
	  [self _setProblem: [NSString stringWithFormat:
	    @"Unable to find port.operation matching '%@'", method]];
	  return NO;
	}
      else
	{
	  NSString	*problem;
          NSArray	*order;

	  /* Handle extensibility for port ...
	   * With SOAP this supplies the URL that we should send to.
	   */
          enumerator = [[_port extensibility] objectEnumerator];
	  while ((elem = [enumerator nextObject]) != nil)
	    {
	      problem = [self _setupFrom: elem in: _port];
	      if (problem != nil)
		{
		  [self _clean];
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
	      problem = [self _setupFrom: elem in: binding];
	      if (problem != nil)
		{
		  [self _clean];
		  [self _setProblem: problem];
		  return NO;
		}
	    }

	  /* Now look at operation specific parameter ordering defined in
	   * the abstract operation in the portType. 
	   */
	  order = [[[operation attributes] objectForKey: @"parameterOrder"]
	    componentsSeparatedByString: @" "];
	  if ([order count] > 0)
	    {
	      NSMutableArray	*m = [order mutableCopy];
	      unsigned		c = [m count];

	      while (c-- > 0)
		{
		  NSString	*s = [order objectAtIndex: c];

		  if ([_parameters objectForKey: s] == nil)
		    {
		      /* Item is not present in parameters dictionary so
		       * presumably it' an output parameter rather than
		       * an input parameter ad we can ignore it.
		       */
		      [m removeObjectAtIndex: c];
		    }
		}
	      if ([m count] > 0)
		{
		  /* Add the ordering information to the parameters dictionary
		   * so that the coder will be able to use it.
		   */
		  [_parameters setObject: m forKey: GWSOrderKey];
		}
	      [m release];
	    }

	  /* Next we can examine the specific operation binding information.
	   */
	  elem = [binding operationWithName: _operation create: NO];
	  elem = [elem firstChild];
	  while (elem != nil
	    && [[elem name] isEqualToString: @"input"] == NO
	    && [[elem name] isEqualToString: @"output"] == NO)
	    {
	      problem = [self _setupFrom: elem in: binding];
	      if (problem != nil)
		{
		  [self _clean];
		  [self _setProblem: problem];
		  return NO;
		}
	      elem = [elem sibling];
	    }
          if ([[elem name] isEqualToString: @"input"] == YES)
	    {
	      elem = [elem firstChild];
	      while (elem != nil)
		{
		  problem = [self _setupFrom: elem in: binding];
		  if (problem != nil)
		    {
		      [self _clean];
		      [self _setProblem: problem];
		      return NO;
		    }
		  elem = [elem sibling];
		}
	    }
	}
    }

  if (_coder == nil)
    {
      [self _clean];
      [self _setProblem: @"no coder set  (use -setCoder:)"];
      return NO;
    }
  [_coder setDebug: [self debug]];
  if (_connectionURL == nil)
    {
      [self _clean];
      [self _setProblem: @"no URL string set  (use -setURL:)"];
      return NO;
    }

  [self _setProblem: @"unable to send"];

  if (_timer != nil)
    {
      [self _clean];
      return NO;	// Send already in progress.
    }

  _request = [_coder buildRequest: method parameters: _parameters order: order];
  if (_request == nil)
    {
      [self _clean];
      return NO;
    }
  if (_delegate != nil)
    {
      _request = [_delegate webService: self willSendRequest: _request];
    }
  [_request retain];

  _timer = [NSTimer scheduledTimerWithTimeInterval: seconds
					    target: self
					  selector: @selector(timeout:)
					  userInfo: nil
					   repeats: NO];
  if (_clientCertificate == nil)
    {
      NSMutableURLRequest   *request;

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
      [request setHTTPBody: _request];

      _connection = [NSURLConnection alloc];
      _connection = [_connection initWithRequest: request delegate: self];
      [request release];
    }
  else
    {
#if	defined(GNUSTEP)
      NSURL	*u = [NSURL URLWithString: _connectionURL];
        
      _connection = (NSURLConnection*)[[u URLHandleUsingCache: NO] retain];
      if (_clientCertificate != nil)
	{
	  [handle writeProperty: _clientCertificate 
			 forKey: GSHTTPPropertyCertificateFileKey];
	}
      if (_clientKey != nil)
	{
	  [handle writeProperty: _clientKey forKey: GSHTTPPropertyKeyFileKey];
	}
      if (_clientPassword != nil)
	{
	  [handle writeProperty: _clientPassword
			 forKey: GSHTTPPropertyPasswordKey];
	}
      if (_SOAPAction != nil)
	{
	  [handle writeProperty: _SOAPAction forKey: @"SOAPAction"];
	}
      [handle addClient: (id<NSURLHandleClient>)self];
      [handle writeProperty: @"POST" forKey: GSHTTPPropertyMethodKey];
      [handle writeProperty: @"GWSService/0.1.0" forKey: @"User-Agent"];
      [handle writeProperty: @"text/xml" forKey: @"Content-Type"];
      [handle writeData: _request];
      [handle loadInBackground];
#endif
    }
  return YES;
}

- (void) setCoder: (GWSCoder*)aCoder
{
  if (aCoder != _coder)
    {
      GWSCoder   *old = _coder;

      if ([aCoder delegate] != nil)
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Coder already had a delegate"];
	}
      _coder = nil;
      if ([old delegate] == (id)self)
	{
          [old setDelegate: nil];
	}
      _coder = [aCoder retain];
      [old release];
      [_coder setDelegate: self];
    }
}

- (void) setCompact: (BOOL)flag
{
  _compact = flag;
}

- (void) setDebug: (BOOL)flag
{
  _debug = flag;
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

#if	!defined(GNUSTEP)
  if (cert != nil)
    {
      [NSException raise: NSInvalidArgumentException
	          format: @"Client certificates not supported on MacOS-X"];
    }
#endif
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
  old = _clientCertificate;
  _clientCertificate = [cert copy];
  [old release];
  old = _clientKey;
  _clientKey = [pKey copy];
  [old release];
  old = _clientPassword;
  _clientPassword = [pwd copy];
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
#if	defined(GNUSTEP)
  if ([_connection isKindOfClass: [NSURLConnection class]])
    {
      [_connection cancel];
    }
  else
    {
      [handle cancelLoadInBackground];
    }
#else
  [_connection cancel];
#endif
  [self _completed];
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
      if (_delegate != nil)
	{
	  NSData	*data;

	  data = [_delegate webService: self willHandleResponse: _response];
	  if (data != _response)
	    {
	      [_response release];
	      _response = [data retain];
	    }
	}
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
  [_result retain];

  [_timer invalidate];
  _timer = nil;
  [self _completed];
}

- (NSString*) webServiceOperation
{
  return _operation;
}

- (NSMutableDictionary*) webServiceParameters
{
  return _parameters;
}

- (GWSPort*) webServicePort
{
  return _port;
}

@end

@implementation	GWSService (Delegate)
- (void) completedRPC: (GWSService*)sender
{
}
- (NSData*) webService: (GWSService*)sender willSendRequest: (NSData*)data
{
  return data;
}
- (NSData*) webService: (GWSService*)sender willHandleResponse: (NSData*)data
{
  return data;
}
@end

#if	defined(GNUSTEP)
@implementation	GWSService (NSURLHandle)

- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData
{
  return;	// Not interesting
}

- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
  [_timer invalidate];
  _timer = nil;
  [handle removeClient: (id<NSURLHandleClient>)self];
  [self _setProblem: reason];
  [self _completed];
}

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender
{
  return;	// Not interesting
}

- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender
{
  NSString	*str;

  [_timer invalidate];
  _timer = nil;
  [handle removeClient: (id<NSURLHandleClient>)self];
  str = [handle propertyForKeyIfAvailable: NSHTTPPropertyStatusCodeKey];
  if (str == nil)
    {
      str = @"timeout";
    }
  else
    {
      str = [NSString stringWithFormat: @"HTTP status %@", str];
    }
  [self _setProblem: str];
  [self _completed];
}

- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender
{
  int	code;

  [_timer invalidate];
  _timer = nil;
  [handle removeClient: (id<NSURLHandleClient>)self];

  code = [[handle propertyForKey: NSHTTPPropertyStatusCodeKey] intValue];
  if (code == 200)
    {
      _response = [[handle availableResourceData] retain];
    }
  else
    {
      NSString	*str;

      str = [NSString stringWithFormat: @"HTTP status %03d", code];
      [self _setProblem: str];
      [self _completed];
      return;
    }

  if (_result != nil)
    {
      [_result release];
      _result = nil;
    }
  NS_DURING
    {
      if (_delegate != nil)
	{
	  NSData	*data;

	  data = [_delegate webService: self willHandleResponse: _response];
	  if (data != _response)
	    {
	      [_response release];
	      _response = [data retain];
	    }
	}
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
  [_result retain];

  [self _completed];
}
@end
#endif
