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

   $Date: 2007-09-14 13:54:55 +0100 (Fri, 14 Sep 2007) $ $Revision: 25485 $
   */ 

#ifndef	INCLUDED_GWSSERVICE_H
#define	INCLUDED_GWSSERVICE_H

#import <Foundation/NSObject.h>

#if     defined(__cplusplus)
extern "C" {
#endif

@class  NSMutableData;
@class  NSString;
@class  NSTimer;
@class  NSTimeZone;
@class  NSURLConnection;
@class  GWSCoder;
@class  GWSDocument;
@class  GWSElement;
@class  GWSPort;

/**
 * <p>The GWSService class provides methods for makeing a Remote Procedure
 * Call (RPC) as a web services client.<br />
 * Instances of this class are (in an ideal world) created and owned by
 * instances the GWSDocument class as it parses a WSDL document, and contain
 * information parsed from that document allowing them to set up the coding
 * mechanism and URL to talk to.<br />
 * However, standalone instances may be created to allow you to perform RPCs
 * to a web services server when you dont have a fully specified WSDL document
 * (or if the GWSDocument mechanism isn't working).
 * </p>
 * <p>The class provides a method for making a synchronous RPC (with timeout),
 * or an asynchronous RPC in which the call completion is handled by a delegate.
 * </p>
 * <p>In order to simply make a synchronous call to a server, all
 * you need to do is write code like:
 * </p>
 * <example>
 *   GWSService	*server;
 *   NSDictionary       *result;
 *   server = [GWSService new];
 *   [server setURL: @"http://server/path"];
 *   [server setCoder: [GWSSOAPCoder coder]];
 *   result = [server invokeMethod: name
 *                      parameters: p
 *                           order: o
 *                         timeout: 30];
 * </example>
 * <p>Saying that you want to call the specified method ('name') on  the server,
 * passing the parameters ('p') in the order they are listed in 'o'
 * and with a 30 second timeout.<br />
 * If there is a network or http-level error or a timeout, the result
 * will contain <ref type="constant" id="GWSErrorKey">GWSErrorKey</ref>,
 * otherwise it will contain 
 * <ref type="constant" id="GWSParametersKey">GWSParametersKey</ref>,
 * and <ref type="constant" id="GWSOrderKey">GWSOrderKey</ref> on success,
 * or <ref type="constant" id="GWSFaultKey">GWSFaultKey</ref> if the remote
 * end returns a fault.
 * </p>
 */
@interface	GWSService : NSObject
{
@private
  NSString              *_name;
  GWSDocument           *_document;     // Not retained (our owner)
  GWSElement            *_documentation;
  NSMutableDictionary   *_ports;
  NSMutableArray        *_extensibility;
  NSString		*_connectionURL;
  NSURLConnection	*_connection;
  NSMutableData		*_response;
  NSTimer		*_timer;
  NSMutableDictionary	*_result;
  id			_delegate;	// Not retained.
  NSTimeZone		*_tz;
  GWSCoder              *_coder;
  NSString		*_SOAPAction;
  BOOL			_compact;
  BOOL			_debug;
  NSString		*_operation;
  GWSPort		*_port;
  NSMutableDictionary	*_parameters;
  NSData		*_request;
  NSString		*_clientCertificate;
  NSString		*_clientKey;
  NSString		*_clientPassword;
}

/**
 * Builds an RPC method call.<br />
 * The method argument is the name of the operation to be performed,
 * however, if the receiver is owned by a GWSDocument instance which
 * defines multiple ports for the service, the operation name may not
 * be unique, in which case it must be specified as the port type and
 * operation names separated by a full stop (port.operation).<br />
 * Parameters must be supplied as for the
 * [GWSCoder-buildRequest:parameters:order:] method.<br />
 */
- (NSData*) buildRequest: (NSString*)method
              parameters: (NSDictionary*)parameters
                   order: (NSArray*)order;

/**
 * Returns the coder instance used to serialize/deserialize for this
 * instance.<br />
 */
- (GWSCoder*) coder;

/** Returns YES if debug is enabled, NO otherwise.  The default value of this
 * is obtained from the GWSDebug user default (or NO if no default
 * is set), but may also be adjusted by a call to the -setDebug: method.
 */
- (BOOL) debug;

/**
 * Returns the delegate previously set by the -setDelegate: method.<br />
 * The delegate handles completion of asynchronous method calls to the
 * URL specified when the receiver was initialised (if any).
 */
- (id) delegate;

/** Return the documentation for the receiver.
 */
- (GWSElement*) documentation;

/**
 * Calls -sendRequest:parameters:order:timeout: and waits for the
 * response.<br />
 * Parameters must be supplied as for the
 * [GWSCoder-buildRequest:parameters:order:] method.<br />
 * Returns the response dictionary containing values for the
 * success or failure of the call (as returned by -result).<br />
 */
- (NSMutableDictionary*) invokeMethod: (NSString*)method
                           parameters: (NSDictionary*)parameters
                                order: (NSArray*)order
                              timeout: (int)seconds;

/** Returns the name of this WSDL service.
 */
- (NSString*) name;

/**
 * Returns the result of the last method call, or nil if there has been
 * no method call or one is in progress.<br />
 * The result is as produced by the [GWSCoder-parseMessage:] method.<br />
 * NB. Any containers (arrays or dictionaries) in the parsed parameters
 * of a success response will be mutable, so you can modify this data
 * structure as you like.
 */
- (NSMutableDictionary*) result;

/**
 * Send an asynchronous RPC method call with the specified timeout.<br />
 * The method argument is the name of the operation to be performed,
 * however, if the receiver is owned by a GWSDocument instance which
 * defines multiple ports for the service, the operation name may not
 * be unique, in which case it must be specified as the port type and
 * operation names separated by a full stop (port.operation).<br />
 * A delegate should have been set to handle the result of this call,
 * but if one was not set the state of the asynchronous call may be polled
 * by calling the -result method, which will return nil as long as the
 * call has not completed.<br />
 * The call may be cancelled by calling the -timeout: method<br />
 * This method returns YES if the call was started,
 * NO if it could not be started
 * (eg because another call is in progress or because of bad arguments).<br />
 * NB. For the asynchronous operation to proceed, the current [NSRunLoop]
 * must be run.<br />
 * Parameters must be supplied as for the
 * [GWSCoder-buildRequest:parameters:order:] method.<br />
 */
- (BOOL) sendRequest: (NSString*)method
          parameters: (NSDictionary*)parameters
               order: (NSArray*)order
             timeout: (int)seconds;

/** Sets the coder to be used by the receiver for encoding to XML and
 * decoding from XML.  If this is not called, the receiver creates a
 * coder as needed.<br />
 * Calling this method sets the receiver as the delegate of the coder,
 * or raises an NSInvalidArgumentException if the coder already had a
 * different delegate.
 */
- (void) setCoder: (GWSCoder*)aCoder;

/** Specifies whether debug information is enabled.  See -debug for more
 * information.
 */
- (void) setDebug: (BOOL)flag;

/**
 * Sets the delegate object which will receive callbacks when an RPC
 * call completes.<br />
 * NB. this delegate is <em>not</em> retained, and should be removed
 * before it is deallocated (call -setDelegate: again with a nil argument
 * to remove the delegate).
 */
- (void) setDelegate: (id)aDelegate;

/** Set the documentation for the receiver.
 */
- (void) setDocumentation: (GWSElement*)documentation;

/**
 * Sets the value of the SOAPAction header to be sent with a request.<br />
 * Setting an nil string value suppresses the sending of this header.<br />
 * Most servers expect two double quotes characters for this,
 * so you should probably set @&quot;\&quot;\&quot;&quot; as the action.<br />
 */
- (void) setSOAPAction: (NSString*)action;

/**
 * Sets the time zone for use when sending/receiving date/time values.<br />
 * The XMLRPC specification says that timezone is server dependent so you
 * will need to set it according to the server you are connecting to.<br />
 * If this is not set, UCT is assumed.
 */
- (void) setTimeZone: (NSTimeZone*)timeZone;

/**
 * Sets up the receiver to make XMLRPC calls to the specified URL.<br />
 * This method just calls -initWithURL:certificate:privateKey:password:
 * with nil arguments for the SSL credentials.
 */
- (void) setURL: (id)url;

/**
 * Sets up the receiver to make XMLRPC calls to the specified url
 * and (optionally) with the specified SSL parameters.<br />
 * The url argument may be nil, in which case the receiver will be
 * unable to make XMLRPC calls, but can be used to parse incoming
 * requests and build responses.<br />
 * The url can actually be either a string or an instance of NSURL.<br />
 * If the SSL credentials are non-nil, connections to the remote server
 * will be authenticated using the supplied certificate so that the
 * remote system knows who is contacting it.<br />
 * Certificate based authentication currently <em>NOT</em> implemented
 ** for MacOS-X (though it is for GNUstep).<br />
 * Please could someone let me know how
 * certificate based authentication is done for HTTPS on MacOS-X?
 */
- (void) setURL: (id)url
    certificate: (NSString*)cert
     privateKey: (NSString*)pKey
       password: (NSString*)pwd;

/**
 * Handles timeouts, passing information to delegate ... you don't need to
 * call this method, but you <em>may</em> call it in order to cancel an
 * asynchronous request as if it had timed out.
 */
- (void) timeout: (NSTimer*)t;

/**
 * Return the time zone currently set.
 */
- (NSTimeZone*) timeZone;

/** Return a tree representation of the receiver for output as part of
 * a WSDL document.
 */
- (GWSElement*) tree;

/** Returns the name of the current operation being performed,
 * or nil if there is no operation in progress.<br />
 * In conjunction with -webServicePort this method can be used to look
 * up all the details of the WSDL definition of the operation being
 * performed.
 */
- (NSString*) webServiceOperation;

/** Returns the parameter dictionary of the current operation being performed,
 * or nil if there is no operation in progress.<br />
 * This method can be used to determine exactly what data is being passed
 * in the current operation.
 */
- (NSMutableDictionary*) webServiceParameters;

/** Returns the port of the current operation being performed,
 * or nil if there is no operation in progress.<br />
 * In conjunction with -webServiceOperation this method can be used to look
 * up all the details of the WSDL definition of the operation being
 * performed.
 */
- (GWSPort*) webServicePort;

@end

/**
 * Delegates should implement this method in order to be informed of
 * the success or failure of an XMLRPC method call which was initiated
 * by the -sendRequest:parameters:order:timeout: method.<br />
 */
@interface	GWSService (Delegate)

/** <override-dummy />
 * Called by the sender when an RPC method call completes (either success
 * or failure). 
 * The delegate may then call the -result method to retrieve the result of
 * the method call from the sender.
 */
- (void) completedRPC: (GWSService*)sender;

/** <override-dummy />
 * Called by the sender when it is about to send an encoded request to a
 * remote server.  The delegate may return a different data item to be
 * sent and/or take this opportunity to change the service settings
 * (such as the URL to send to) before the data is actualy sent.
 */
- (NSData*) webService: (GWSService*)sender willSendRequest: (NSData*)data;

/** <override-dummy />
 * Called by the sender when it is about to handle response data from a
 * remote server.  The delegate may return a different data item to be
 * decoded and/or take this opportunity to change the service settings
 * before the response is handled.
 */
- (NSData*) webService: (GWSService*)sender willHandleResponse: (NSData*)data;

/** This method is used to inform the delegate of the
 * GWSElement instance being decoded as the SOAP Envelope, Header, Body,
 * Fault or Method.<br />
 * The instance to be decoded will contain the children from the
 * document being decoded.<br />
 * The delegate implementation should return the proposed instance
 * (possibly modified) or a different object that it wishes the
 * coder to use.
 */
- (GWSElement*) webService: (GWSService*)service
		willDecode: (GWSElement*)element;

/** This method is used to inform the delegate of the proposed
 * [GWSElement] instance used to encode SOAP Envelope, Header, Body, Fault
 * or Method elements.<br />
 * The proposed instance will not have any children at the point
 * where this method is called (they are added later in the
 * encoding process.<br />
 * This method may be called with a nil value for the element parameter in
 * the case where no Header element would be encoded ... in this situation
 * the delegate may return a Header element to be used, or may return some
 * other element, which will be automatically inserted into a standard
 * header.<br />
 * The delegate implementation should return the proposed instance
 * (possibly modified) or a different object that it wishes the
 * coder to encode instead.<br />
 * The default implementation returns element.<br />
 * NB. A Fault or Method will obviously only be provided where the message
 * contain such an element, and the Header will only be provided where
 * the message has been told to contain headers by use of the
 * <ref type="constant" id="GWSSOAPMessageHeadersKey">
 * GWSSOAPMessageHeadersKey</ref> in the parameters dictionary.
 */
- (GWSElement*) webService: (GWSService*)service
		willEncode: (GWSElement*)element;

@end



#if	defined(__cplusplus)
}
#endif

#endif

