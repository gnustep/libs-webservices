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

#ifndef	INCLUDED_GWSCONSTANTS_H
#define	INCLUDED_GWSCONSTANTS_H

#import	<Foundation/NSString.h>

#if     defined(__cplusplus)
extern "C" {
#endif

/** Key for a local error returned in a result dictionary.<br />
 * If an error occurred at the local end while producing the result
 * dictionary, the value for this key (and NSError, NSException, or NSString)
 * will describe the nature of the problem.
 */
extern NSString * const GWSErrorKey;

/** Key for a fault dictionary returned in a response dictionary.<br />
 * The value for this key is nil unless a wsdl <em>fault</em>
 * was decoded into the dictionary.
 */
extern NSString * const GWSFaultKey;

/** Key for the method name in a request dictionary.<br />
 * The value of this key is nil unless the dictionary was the result of
 * decoding a request, in which case it is the name of the method/operation
 * requested.
 */
extern NSString * const GWSMethodKey;

/** Key for an ordering array in a request or response dictionary.<br />
 * If present in a decoded object, the value of this key is an
 * NSMutableArray object containing the names of the parameters decoded.<br />
 * If present in a dictionary being encoded, this is an NSArray object
 * specifying the order in which the members of the dictionary are to be
 * encoded.
 */
extern NSString * const GWSOrderKey;

/** Key for a parameters dictionary in a request or response dictionary.<br />
 * If present, the value of this key is an NSMutableDictionary containing
 * the decoded parameters.
 */
extern NSString * const GWSParametersKey;

/** Key for the data sent to a remote system to perform a GWSService RPC
 * operation.<br />
 * This is present if debug was enabled for the service,
 * but is omitted otherwise.
 */
extern NSString * const GWSRequestDataKey;

/** Key for the data from a remote system returned in a result
 * of a GWSService RPC made to a web services server.<br />
 * This is present if and debug was enabled
 * for the service, but is omitted otherwise.
 */
extern NSString * const GWSResponseDataKey;


/** Key for the encoding style to be used for the SOAP body.<br />
 * The value of this may be one of
 * <list>
 * <item><ref type="constant" id="GWSSOAPBodyEncodingStyleDocument">
 * GWSSOAPBodyEncodingStyleDocument</ref></item>
 * <item><ref type="constant" id="GWSSOAPBodyEncodingStyleRPC">
 * GWSSOAPBodyEncodingStyleRPC</ref></item>
 * <item><ref type="constant" id="GWSSOAPBodyEncodingStyleWrapped">
 * GWSSOAPBodyEncodingStyleWrapped</ref></item>
 * </list>
 */
extern NSString * const GWSSOAPBodyEncodingStyleKey;

/** This means that the SOAP body is encoded in document style.<br />
 * Setting this value for the GWSSOAPBodyEncodingStyleKey in the
 * parameters of a message being encoded has the same effect as
 * calling [GWSSOAPCoder-setOperationStyle:]
 * with an argument of GWSSOAPBodyEncodingStyleDocument.
 */
extern NSString * const GWSSOAPBodyEncodingStyleDocument;

/** This means that the SOAP body is encoded in RPC style.<br />
 * Setting this value for the GWSSOAPBodyEncodingStyleKey in the
 * parameters of a message being encoded has the same effect as
 * calling [GWSSOAPCoder-setOperationStyle:]
 * with an argument of GWSSOAPBodyEncodingStyleRPC.
 */
extern NSString * const GWSSOAPBodyEncodingStyleRPC;

/** This means that the SOAP body is encoded in wrapped style.<br />
 * Setting this value for the GWSSOAPBodyEncodingStyleKey in the
 * parameters of a message being encoded has the same effect as
 * calling [GWSSOAPCoder-setOperationStyle:]
 * with an argument of GWSSOAPBodyEncodingStyleWrapped.<br />
 * NB. This encoding style is not yet implemented.
 */
extern NSString * const GWSSOAPBodyEncodingStyleWrapped;

/** Key for the 'use' style to be used for the SOAP body.<br />
 * The value of this key may be 'literal' or 'encoded'.
 */
extern NSString * const GWSSOAPBodyUseKey;

/** Key for the 'use' style to be used for the SOAP header.<br />
 * The value of this key may be 'literal' or 'encoded'.
 * <ref type="constant" id="GWSSOAPUseEncoded">GWSSOAPUseEncoded</ref> or
 * <ref type="constant" id="GWSSOAPUseLiteral">GWSSOAPUseLiteral</ref>
 */
extern NSString * const GWSSOAPHeaderUseKey;

/** Constant 'encoded' for body/header use.<br />
 * If data is 'encoded', each element of the data has a 'type' attribute
 * which provides type information allowing the element contents to be
 * be decoded.
 */
extern NSString * const GWSSOAPUseEncoded;

/** Constant 'literal' for body/header use.<br />
 * If data is 'literal', the contents of elements are decoded by implicit
 * type knowledge depending on the element name and its position within 
 * the XML document.
 */
extern NSString * const GWSSOAPUseLiteral;

/** Key for the header element for a soap message.<br />
 * A dictionary of message parts (like the parameters dictionary itsself)
 * may be specified for the contents of the header.<br />
 * Alternatively, you may some object other than a populated dictionary
 * for this key, in which case the coder will generate an empty header
 * element which the coder's delegate can then modify.<br />
 * If no value is set for this key, the header element is omitted.
 */
extern NSString * const GWSSOAPMessageHeadersKey;

/** Key for the URI to be used as the default namespace for the
 * current element (and all elements within it, unless overriden).<br />
 * As a special case at the SOAP Body, Fault, or Header level,
 * if this key is used in conjunction with the GWSSOAPNamespaceNameKey,
 * a mapping is set up in the SOAP Envelope to match the name to the URI.
 * This behavior is in addition to the normal behaqvior of setting the
 * default namespace.
 */
extern NSString * const GWSSOAPNamespaceURIKey;

/** Key for the name to be used for the namespace of the current element
 * (ie as the namespace prefix before the element name).<br />
 * For instance.
 * <example>
 * foo = {
 *   GWSSOAPnamespaceNameKey = "xxx";
 * };
 * </example>
 * means that the element is encoded as 'xxx:foo' rather than just 'foo'.<br />
 * This has a special meaning at the level of the SOAP Body, Fault, or
 * Header dictionary.  In these cases it does not set the namespace prefix
 * for that element, but is instead used in conjunction with the
 * GWSSOAPNamespaceURIKey to set up a namespace mapping in the SOAP Envelope.
 */
extern NSString * const GWSSOAPNamespaceNameKey;

/** If this key is present in a dictionary, then instead of treating the
 * dictionary as a complex type, the value referenced by this key is
 * encoded, and other values in the dictionary (eg. GWSSOAPNamespaceURIKey)
 * are used to modify the encoding of that value.<br />
 * eg.
 * <example>
 * foo = {
 *   GWSSOAPValueKey = "hello";
 *   GWSSOAPNamespaceURIKey = "http://foo/xxx.xsd";
 * };
 * </example>
 * would encode '&lt;foo "xmlns=http://foo/xxx.xsd"&gt;hello&lt;/foo&gt;'.
 */
extern NSString * const GWSSOAPValueKey;
#if	defined(__cplusplus)
}
#endif

#endif

