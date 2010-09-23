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
#import <Performance/GSThreadPool.h>

static NSRecursiveLock	*queueLock = nil;
static unsigned perHostPool = 20;
static unsigned perHostQMax = 200;
static unsigned	pool = 200;
static unsigned	qMax = 2000;
static unsigned	activeCount = 0;
static GSThreadPool		*thread = nil;
static NSMutableDictionary	*active = nil;
static NSMutableDictionary	*queues = nil;
static NSMutableArray		*queued = nil;

/* Return YES if there is an available slot to send a request to the
 * specified host, NO otherwise.
 * The global lock must be locked before this is called.
 */
static BOOL
available(NSString *host)
{
  if (activeCount >= pool)
    {
      return NO;
    }
  if (host != nil && [[active objectForKey: host] count] < perHostPool)
    {
      return YES;
    }
  return NO;
}

/* To support client side SSL certificate authentication we use the old
 * NSURLHandle stuff with GNUstep extensions.  We use the _connection
 * ivar to hold the handle in this case.
 */
#define	handle	((NSURLHandle*)_connection)

#if	defined(GNUSTEP)
@interface	NSURLHandle (Debug)
- (void) setDebug: (BOOL)flag;
- (void) setReturnAll: (BOOL)flag;
@end
#endif

@implementation	GWSService (Private)
+ (void) _run: (NSString*)host
{
  NSMutableArray	*a = nil;

  [queueLock lock];
  if (activeCount < pool && [queued count] > 0)
    {
      unsigned	i;

      if (available(host) == YES)
	{
	  NSArray	*q = [queues objectForKey: host];

	  if ([q count] > 0)
	    {
	      GWSService	*svc = [q objectAtIndex: 0];

	      [svc _activate];
	      if (nil == a) a = [[NSMutableArray alloc] initWithCapacity: 100];
	      [a addObject: svc];
	    }
	}
      for (i = 0; activeCount < pool && i < [queued count]; i++)
	{
	  GWSService	*svc = [queued objectAtIndex: i];

	  if (available([svc->_connectionURL host]) == YES)
	    {
	      [svc _activate];
	      if (nil == a) a = [[NSMutableArray alloc] initWithCapacity: 100];
	      [a addObject: svc];
	    }
	}
    }
  [queueLock unlock];
  [a makeObjectsPerformSelector: @selector(_start)];
  [a release];
}

/* NB. This must be called with the global lock already locked.
 */
- (void) _activate
{
  NSString		*host;
  NSMutableArray	*hostQueue;

  /* Add self to active list.
   * Keep the count of active requests up to date.
   */
  host = [_connectionURL host];
  hostQueue = [active objectForKey: host];
  if (hostQueue == nil)
    {
      hostQueue = [NSMutableArray new];
      [active setObject: hostQueue forKey: host];
      [hostQueue release];
    }
  [hostQueue addObject: self];
  activeCount++;

  /* The next two lines will do nothing if the receiver was not
   * queued before activation.  We need them for the case where
   * we were queued and are now being activated.
   * Removal from the queue is done *after* addition to the
   * active list to ensure that the receiver is not deallocated.
   */
  [[queues objectForKey: host] removeObjectIdenticalTo: self];
  [queued removeObjectIdenticalTo: self];
}

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
  /* We can safely call this more than once, since we do nothing unless
   * a request is actually in progress.
   */
  if (_request != nil)
    {
      NSString		*host;
      NSMutableArray	*a;
      NSUInteger	index;

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

      /* Retain self and host in case the delegate changes the URL
       * or releases us (or removing self from active list would
       * cause deallocation).
       */
      [[self retain] autorelease];
      host = [[[_connectionURL host] retain] autorelease];

      /* Now make sure the receiver is no longer active.
       * This must be done before informing the delegate of
       * completion, in case the delegate wants to schedule
       * another request to the same host.
       */
      [queueLock lock];
      a = [active objectForKey: host];
      index = [a indexOfObjectIdenticalTo: self];
      if (index == NSNotFound)
	{
	  /* Must have timed out while still in local queue.
	   */
	  [[queues objectForKey: host] removeObjectIdenticalTo: self];
	  [queued removeObjectIdenticalTo: self];
	}
      else
	{
	  [a removeObjectAtIndex: index];
	  activeCount--;
	}
      [queueLock unlock];
      [GWSService _run: host];	// start any queued requests for host

      if ([_delegate respondsToSelector: @selector(completedRPC:)])
	{
	  [_delegate completedRPC: self];
	}
    }
}

- (BOOL) _enqueue
{
  BOOL	result = NO;

  [queueLock lock];
  if ([queued count] < qMax)
    {
      NSString		*host = [_connectionURL host];
      NSMutableArray	*hostQueue = [queues objectForKey: host];

      if ([hostQueue count] < perHostQMax)
	{
	  if (hostQueue == nil)
	    {
	      hostQueue = [NSMutableArray new];
	      [queues setObject: hostQueue forKey: host];
	      [hostQueue release];
	    }
	  if (YES == _prioritised)
	    {
	      unsigned	count;
	      unsigned	index;

	      count = [hostQueue count];
	      for (index = 0; index < count; index++)
		{
		  GWSService	*tmp = [hostQueue objectAtIndex: index];

		  if (tmp->_prioritised == NO)
		    {
		      break;
		    }
		}
	      [hostQueue insertObject: self atIndex: index];

	      count = [queued count];
	      for (index = 0; index < count; index++)
		{
		  GWSService	*tmp = [queued objectAtIndex: index];

		  if (tmp->_prioritised == NO)
		    {
		      break;
		    }
		}
	      [queued insertObject: self atIndex: index];
	    }
	  else
	    {
	      [hostQueue addObject: self];
	      [queued addObject: self];
	    }
	  result = YES;
	}
    }
  [queueLock unlock];
  return result;
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

- (void) _received
{
  if (_result != nil)
    {
      [_result release];
      _result = nil;
    }

  if (_code != 200 && [_coder isKindOfClass: [GWSXMLRPCCoder class]] == YES)
    {
      NSString	*str;

      str = [NSString stringWithFormat: @"HTTP status %03d", _code];
      [self _setProblem: str];
    }
  else if (_code != 204 && [_response length] == 0)
    {
      NSString	*str;

      /* Unless we got a 204 response, we expect to have a body to parse.
       */
      if (_code == 200)
	{
          str = [NSString stringWithFormat: @"HTTP status 200 but no body"];
	}
      else
	{
          str = [NSString stringWithFormat: @"HTTP status %03d", _code];
	}
      [self _setProblem: str];
    }
  else
    {
      /* OK ... parse the body ... which should contain some sort of data
       * unless we had a 204 response (some services may accept an empty
       * response, even though xmlrpc and soap do not).
       */
      NS_DURING
	{
	  if ([_delegate respondsToSelector:
	    @selector(webService:willHandleResponse:)] == YES)
	    {
	      NSData	*data;

	      data = [_delegate webService: self willHandleResponse: _response];
	      if (data != _response)
		{
		  [_response release];
		  _response = [data retain];
		}
	    }
	  _result = [[_coder parseMessage: _response] retain];
	}
      NS_HANDLER
	{
	  id        reason = [localException reason];

	  _result = [[NSMutableDictionary alloc] initWithObjects: &reason
						         forKeys: &GWSFaultKey
							   count: 1];
	}
      NS_ENDHANDLER
    }

  [self _completed];
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

- (void) _start
{
  _code = 0;
  if (_clientCertificate == nil
#if	defined(GNUSTEP)
/* GNUstep has better debugging with NSURLHandle than NSURLConnection
 */
&& [self debug] == NO
#endif
    )
    {
      NSMutableURLRequest   *request;

      request = [NSMutableURLRequest alloc];
      request = [request initWithURL: _connectionURL];
      [request setCachePolicy: NSURLRequestReloadIgnoringCacheData];
      [request setHTTPMethod: @"POST"];  
      [request setValue: @"GWSService/0.1.0" forHTTPHeaderField: @"User-Agent"];
      [request setValue: @"text/xml" forHTTPHeaderField: @"Content-Type"];
      if (_SOAPAction != nil)
	{
	  [request setValue: _SOAPAction forHTTPHeaderField: @"SOAPAction"];
	}
      if ([_headers count] > 0)
	{
	  NSEnumerator	*e = [_headers keyEnumerator];
	  NSString	*k;

	  while ((k = [e nextObject]) != nil)
	    {
	      NSString	*v = [_headers objectForKey: k];

	      [request setValue: v forHTTPHeaderField: k];
	    }
	}
      [request setHTTPBody: _request];

      if (_connection != nil)
	{
	  [_connection release];
	}
      _connection = [NSURLConnection alloc];
      _response = [[NSMutableData alloc] init];
      _connection = [_connection initWithRequest: request delegate: self];
      [request release];
    }
  else
    {
#if	defined(GNUSTEP)
      if (_connection == nil)
	{
          _connection = (NSURLConnection*)[[_connectionURL
	    URLHandleUsingCache: NO] retain];
	}
      [handle setDebug: [self debug]];
      if ([handle respondsToSelector: @selector(setReturnAll:)] == YES)
	{
          [handle setReturnAll: YES];
	}
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
      if ([_headers count] > 0)
	{
	  NSEnumerator	*e = [_headers keyEnumerator];
	  NSString	*k;

	  while ((k = [e nextObject]) != nil)
	    {
	      NSString	*v = [_headers objectForKey: k];

	      [handle writeProperty: v forKey: k];
	    }
	}
      [handle writeData: _request];
      [handle loadInBackground];
#endif
    }
}

@end


@implementation	GWSService

+ (void) initialize
{
  if (self == [GWSService class])
    {
      queueLock = [NSRecursiveLock new];
      active = [NSMutableDictionary new];
      queues = [NSMutableDictionary new];
      queued = [NSMutableArray new];
      thread = [GSThreadPool new];
      [thread setThreads: 0];
      [thread setOperations: 0];
    }
}

+ (NSString*) description
{
  NSString	*result;

  [queueLock lock];
  result = [NSString stringWithFormat: @"GWSService async request status..."
    @" Pool: %u (per host: %u) Active: %@ Queues: %@",
    pool, perHostPool, active, queues];
  [queueLock unlock];
  return result;
}

+ (void) setPerHostPool: (unsigned)max
{
  perHostPool = max;
}

+ (void) setPerHostQMax: (unsigned)max
{
  perHostQMax = max;
}

+ (void) setPool: (unsigned)max
{
  pool = max;
}

+ (void) setQMax: (unsigned)max
{
  qMax = max;
}

+ (void) setThreaded: (BOOL)aFlag
{
  [queueLock lock];
  if (YES == aFlag)
    {
      [thread setOperations: pool];
      [thread setThreads: pool];
    }
  else
    {
      [thread setOperations: 0];
      [thread setThreads: 0];
    }
  [queueLock unlock];
}

- (BOOL) beginMethod: (NSString*)method 
           operation: (NSString**)operation
	        port: (GWSPort**)port
{
  if (_operation != nil)
    {
      [self _setProblem: @"Earlier operation still in progress"];
      return NO;
    }

  /* Perhaps the values are being set directly ... if so, we trust them
   */
  if (operation && *operation && port && *port)
    {
      NSString	*o = [*operation retain];
      GWSPort	*p = [*port retain];

      [_operation release];
      _operation = o;
      [_port release];
      _port = p;
      return YES;
    }

  if (_document == nil)
    {
      _operation = [method retain];
    }
  else
    {
      NSRange		r;
      NSString		*portName;
      NSEnumerator	*enumerator;
      GWSElement	*elem;
      GWSPortType	*portType;
      GWSBinding	*binding;

      /* As this is not a standalone service, we must set up information from
       * the parsed WSDL document.
       */
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
	      elem = [[portType operations] objectForKey: _operation];
	      if (elem != nil)
		{
		  if (portName == nil || [portName isEqual: [portType name]])
		    {
		      break;	// matched
		    }
		  elem = nil;
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
    }
  if (operation != 0)
    {
      *operation = _operation;
    }
  if (port != 0)
    {
      *port = _port;
    }
  return YES;
}

- (NSData*) _buildRequest: (NSString*)method 
               parameters: (NSDictionary*)parameters
                    order: (NSArray*)order
{
  if (_parameters != nil)
    {
      [self _setProblem: @"Earlier operation still in progress"];
      return nil;
    }

  if ([self beginMethod: method operation: 0 port: 0] == NO)
    {
      return nil;
    }

  /* Take a mutable copy of the parameters so that we can add keys to it
   * to control encoding options.
   * If there was no parameters dictionary, create an empty one to use.
   */
  _parameters = [parameters mutableCopy];
  if (_parameters == nil)
    {
      _parameters = [NSMutableDictionary new];
    }
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
  if (_port != nil)
    {
      NSEnumerator	*enumerator;
      GWSElement	*elem;
      GWSElement	*operation;
      GWSBinding	*binding;
      GWSPortType	*portType;
      NSString		*problem;
      NSArray		*order;

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
	      return nil;
	    }
	}

      /* Handle SOAP binding ... this supplies the encoding style and
       * transport that we should used.
       */
      binding = [_port binding];
      enumerator = [[binding extensibility] objectEnumerator];
      while ((elem = [enumerator nextObject]) != nil)
	{
	  problem = [self _setupFrom: elem in: binding];
	  if (problem != nil)
	    {
	      [self _clean];
	      [self _setProblem: problem];
	      return nil;
	    }
	}

      /* Now look at operation specific parameter ordering defined in
       * the abstract operation in the portType. 
       */
      portType = [binding type];
      operation = [[portType operations] objectForKey: _operation];
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
		  return nil;
		}
	      elem = [elem sibling];
	    }
	}
    }

  if (_coder == nil)
    {
      [self _clean];
      [self _setProblem: @"no coder set  (use -setCoder:)"];
      return nil;
    }
  [_coder setDebug: [self debug]];
  return [_coder buildRequest: method parameters: _parameters order: order];
}

- (NSData*) buildRequest: (NSString*)method 
              parameters: (NSDictionary*)parameters
                   order: (NSArray*)order
{
  NSData	*req;

  req = [self _buildRequest: method parameters: parameters order: order];
  if (req != nil)
    {
      [self _clean];
    }
  return req;
}

- (GWSCoder*) coder
{
  return _coder;
}

- (GWSElement*) coder: (GWSSOAPCoder*)coder willDecode: (GWSElement*)element
{
  if ([_delegate respondsToSelector: @selector(webService:willDecode:)] == YES)
    {
      element = [_delegate webService: self willDecode: element];
    }
  return element;
}

- (GWSElement*) coder: (GWSSOAPCoder*)coder willEncode: (GWSElement*)element
{
  if ([_delegate respondsToSelector: @selector(webService:willEncode:)] == YES)
    {
      element = [_delegate webService: self willEncode: element];
    }
  return element;
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
  [_headers release];
  [_extra release];
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

- (NSDictionary*) headers
{
  return _headers;
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
  if (_result != nil)
    {
      [_result release];
      _result = nil;
    }
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

- (id) objectForKey: (NSString*)aKey
{
  return [_extra objectForKey: aKey];
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
  return [self sendRequest: method
	        parameters: parameters
		     order: order
		   timeout: seconds
	       prioritised: NO];
}

- (BOOL) sendRequest: (NSString*)method 
          parameters: (NSDictionary*)parameters
               order: (NSArray*)order
             timeout: (int)seconds
	 prioritised: (BOOL)urgent
{
  NSData	*req;

  if (_result != nil)
    {
      [_result release];
      _result = nil;
    }
  if (_response != nil)
    {
      [_response release];
      _response = nil;
    }

  req = [self _buildRequest: method parameters: parameters order: order];
  if (req == nil)
    {
      [self _clean];
      return NO;
    }

  if ([_delegate respondsToSelector:
    @selector(webService:willSendRequest:)] == YES)
    {
      req = [_delegate webService: self willSendRequest: req];
    }
  _request = [req retain];
  _prioritised = urgent;
  _timer = [NSTimer scheduledTimerWithTimeInterval: seconds
					    target: self
					  selector: @selector(timeout:)
					  userInfo: nil
					   repeats: NO];

  [queueLock lock];
  if (available([_connectionURL host]) == YES)
    {
      [self _activate];
      [queueLock unlock];
      [self _start];
      return YES;
    }
  else
    {
      [queueLock unlock];
      return [self _enqueue];
    }
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

- (void) setHeaders: (NSDictionary*)headers
{
  NSDictionary	*tmp = [headers copy];

  [_headers release];
  _headers = tmp;
}

- (void) setObject: (id)anObject forKey: (NSString*)aKey
{
  if (anObject == nil)
    {
      [_extra removeObjectForKey: aKey];
    }
  else
    {
      if (_extra == nil)
	{
	  _extra = [NSMutableDictionary new];
	}
      [_extra setObject: anObject forKey: aKey];
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
  if ([url isKindOfClass: [NSURL class]] == NO)
    {
      NSURL	*u = [NSURL URLWithString: url];
      NSString	*s = [u scheme];

      if (u == nil || [u host] == nil
	|| ([s isEqual: @"http"] == NO && [s isEqual: @"https"] == NO))
	{
	  [NSException raise: NSInvalidArgumentException
		      format: @"Bad URL (%@) supplied", url];
	}
      url = u;
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
  _response = nil;
}

- (void) timeout: (NSTimer*)t
{
  [self retain];
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
  [self release];
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
  _code = [(NSHTTPURLResponse*)response statusCode];
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
  [_timer invalidate];
  _timer = nil;
  if ([_response length] == 0)	// No response received
    {
      [_response release];
      _response = nil;
    }
  [self _received];
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
- (GWSElement*) webService: (GWSService*)service
		willDecode: (GWSElement*)element
{
  return element;
}
- (GWSElement*) webService: (GWSService*)service
		willEncode: (GWSElement*)element
{
  return element;
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
  [_timer invalidate];
  _timer = nil;
  [handle removeClient: (id<NSURLHandleClient>)self];
  [_response release];
  _response = [[handle availableResourceData] retain];
  _code = [[handle propertyForKey: NSHTTPPropertyStatusCodeKey] intValue];
  [self _received];
}
@end
#endif
