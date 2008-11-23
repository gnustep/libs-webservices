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

#ifndef	INCLUDED_GWSCODER_H
#define	INCLUDED_GWSCODER_H

#import <Foundation/NSObject.h>

#if     defined(__cplusplus)
extern "C" {
#endif

@class  NSData;
@class  NSMutableString;
@class  NSString;
@class  NSTimeZone;
@class  GWSBinding;
@class  GWSElement;
@class  GWSPort;
@class  GWSPortType;
@class  GWSService;

/**
 * The GWSCoder class is a semi-abstract class for handling encoding to
 * XML and decoding from XML for a group of services.<br />
 * With its standard instance variables and helper functions it really
 * just provides a convenient mechanism to store data in a mutable
 * string, but in conjunction with [GWSElement] it can be used to
 * serialize a tree of elements to a string and will parse an XML
 * document ninto a tree of elements.<br />
 * Often (for RPC and messaging), the actual encoding/decoding is
 * handled by a concrete subclass.<br />
 * Instances of these classes are not expected to be re-entrant or
 * thread-safe, so you need to create an instance for each thread
 * in which you are working.<br />
 */
@interface	GWSCoder : NSObject
{
  NSMutableArray        *_stack;        // Stack for parsing XML.
@private
  NSMutableDictionary   *_nmap;         // Mapping namespaces.
  NSTimeZone	        *_tz;           // Default timezone.
  BOOL		        _compact;
  unsigned              _level;         // Current indentation level.
  NSMutableString       *_ms;           // Not retained.
  id                    _delegate;      // Not retained.
}

/** Creates and returns an autoreleased instance.<br />
 * The default implementation creates an instance of the GWSXMLRPCCoder
 * concrete subclass.
 */
+ (GWSCoder*) coder;

/**
 * Return the value set by a prior call to -setCompact: (or NO ... the default).
 */
- (BOOL) compact;

/** Decode the supplied base64 encoded data and return the result.
 */
- (NSData*) decodeBase64From: (NSString*)str;

/** Take the supplied data and convert it to base64 encoded text.
 */
- (NSString*) encodeBase64From: (NSData*)source;

/** Take the supplied string and add all necessary escapes for XML.
 */
- (NSString*) escapeXMLFrom: (NSString*)str;

/** Increase the indentation level used while creating an XML document.
 */
- (void) indent;

/** Returns the mutable string currently in use for encoding (if any).
 */
- (NSMutableString*) mutableString;

/** Add a new line to the temporary string currently in use for
 * creating an XML document, and add padding on the new line so
 * that the next item written is indented correctly.
 */
- (void) nl;

/**
 * Parses XML data to form a tree of GWSElement objects.
 */
- (GWSElement*) parseXML: (NSData*)xml;

/**
 * Resets parsing and/or building, releasing any temporary
 * data stored during parse etc.
 */
- (void) reset;

/**
 * Specify whether to generate compact XML (omit indentation and other white
 * space and omit &lt;string&gt; element markup for XMLRPC).<br />
 * Compact representation saves some space (can be important when sent over
 * slow/low bandwidth connections), but sacrifices readability.
 */
- (void) setCompact: (BOOL)flag;

/** Decrease the indentation level used while creating an XML document.
 * creating an XML document.
 */
- (void) unindent;

@end

/** The methods in this category are used to handle web services
 * RPC and messaging tasks.  Most of these methods are implemented
 * by subclasses and cannmot be used in the base class.
 */
@interface      GWSCoder (RPC)

/** Returns the RPC encoding delegate (if any) set by a previous call
 * to the -setDelegate: method.<br />
 * Normally the delagate of a coder is the GWSService instance which owns it.
 */
- (id) delegate;

/** <override-subclass />
 * Constructs an XML document for an RPC fault response with the
 * specified parameters.  The resulting document is returned
 * as an NSData object.<br />
 * For XMLRCP the two parameters should be faultCode (an integer)
 * and faultString.<br />
 * The order array may be empty or nil if the order of the parameters
 * is not important, otherwise it must contain the names of the parameters
 * in the order in which they are to be encoded.<br />
 * This method is intended for use by applications acting as RPC servers.
 */
- (NSData*) buildFaultWithParameters: (NSDictionary*)parameters
                               order: (NSArray*)order;

/** <override-subclass />
 * Given a method name and a set of parameters, this method constructs
 * the XML document for the corresponding message or RPC call and
 * returns the document as an NSData object.<br />
 * The parameters dictionary may be empty or nil if there are no parameters
 * to be passed.<br />
 * The order array may be empty or nil if the order of the parameters
 * is not important, otherwise it must contain the names of the parameters
 * in the order in which they are to be encoded.<br />
 * If composite data types within the parameters dictionary contain fields
 * which must be sent in a specific order, the dictionary containing those
 * fields may contain a key 'GWSOrderKey' whose value is an array containing
 * the names of those fields in the order of their encoding.<br />
 * The method returns nil if passed an invalid method name.<br />
 * This method is used internally when sending an RPC method call to
 * a remote system, but you can also call it yourself.
 */
- (NSData*) buildRequest: (NSString*)method 
              parameters: (NSDictionary*)parameters
                   order: (NSArray*)order;

/** <override-subclass />
 * Builds an RPC response with the specified set of parameters and
 * returns the document as an NSData object.<br />
 * The method name may be nil (and is indeed ignored for XMLRPC) where
 * any parameters are not wrapped inside a method.<br />
 * The parameters dictionary may be empty or nil if there are no parameters
 * to be returned (an empty parameters element will be created).<br />
 * The order array may be empty or nil if the order of the parameters
 * is not important, otherwise it must contain the names of the parameters
 * in the order in which they are to be encoded.<br />
 * This method is intended for use by applications acting as RPC servers.
 */
- (NSData*) buildResponse: (NSString*)method
               parameters: (NSDictionary*)parameters
                    order: (NSArray*)order;

/** <override-subclass />
 * Parses data containing an method call or message etc.<br />
 * The result dictionary may contain
 * <ref type="constant" id="GWSMethodKey">GWSMethodKey</ref>,
 * <ref type="constant" id="GWSParametersKey">GWSParametersKey</ref>,
 * and <ref type="constant" id="GWSOrderKey">GWSOrderKey</ref> on success,
 * or <ref type="constant" id="GWSErrorKey">GWSErrorKey</ref> on failure.<br />
 * NB. Any containers (arrays or dictionaries) in the parsed parameters
 * will be mutable, so you can modify this data structure as you like.<br />
 * This method is intended for the use of server applications.
 */
- (NSMutableDictionary*) parseMessage: (NSData*)data;

/**
 * Sets a delegate to handle decoding and encoding of data items.<br />
 * The delegate should implement the informal GWSCoder protocol to
 * either handle the encoding/decoding or to inform the coder that
 * it won't do it for a particular case.
 */
- (void) setDelegate: (id)delegate;

/**
 * Sets the time zone for use when sending/receiving date/time values.<br />
 * The XMLRPC specification says that timezone is server dependent so you
 * will need to set it according to the server you are connecting to.<br />
 * If this is not set, UCT is assumed.
 */
- (void) setTimeZone: (NSTimeZone*)timeZone;

/**
 * Return the time zone currently set.
 */
- (NSTimeZone*) timeZone;

@end


/** This informal protocol specifies the methods that a coder delegate
 * may implement in order to override general encoding/decoding of
 * service arguments.<br />
 * Generally the delegate is a GWSService instance.
 */
@interface      NSObject(GWSCoder)

/** This method is called to ask the delegate to decode the specified
 * element and return the result.  If the delegate does not wish to
 * decode the element, it should simply return nil.<br />
 * The name and index arguments provide context for decoding, allowing the
 * delegate to better understand how the element should be decoded... the
 * index is the position of the item in the ordered list of items being
 * decoded, and the name is the identifier that will be used for the item.<br />
 * The default implementation returns nil.
 */
- (id) decodeWithCoder: (GWSCoder*)coder
                  item: (GWSElement*)item
                 named: (NSString*)name
                 index: (unsigned)index;
/** This method is called to ask the delegate to encode the specified item
 * with the given name and array index where appropriate.<br />
 * The delegate must return nil if it does not wish to encode the item
 * itsself, otherwise it must return an autoreleased [GWSElement]
 * instance containing the XML representing the encoded value.<br />
 * The name is the key used to identify the item in the parameters
 * dictionary and index is the position of the item in the ordering
 * array (or NSNotFound if the item is not part of the parameters
 * dictionary).<br />
 * The delegate may use the [GWSElement-setLiteralValue:] method
 * to create and return an element which will appear as arbitrary
 * text in the output document.<br />
 * The default implementation returns nil.
 */
- (GWSElement*) encodeWithCoder: (GWSCoder*)coder
                           item: (id)item
                          named: (NSString*)name
                          index: (unsigned)index;

/** Returns the name of the operation that the receiver is being
 * used to implement.
 */
- (NSString*) webServiceOperation;

/** Returns the port object defining the binding and address of
 * the operation being performed.
 */
- (GWSPort*) webServicePort;
@end


/** <p>The GWSXMLRPCCoder class is a concrete subclass of [GWSCoder] which
 * implements coding/decoding for the XMLRPC protocol.
 * </p>
 * <p>The correspondence between XMLRPC values and Objective-C objects
 * is as follows -
 * </p>
 * <list>
 *   <item><strong>i4</strong>
 *   (or <em>int</em>) is an [NSNumber] other
 *   than a real/float or boolean.</item>
 *   <item><strong>boolean</strong>
 *   is an [NSNumber] created as a BOOL.</item>
 *   <item><strong>string</strong>
 *   is an [NSString] object.</item>
 *   <item><strong>double</strong>
 *   is an [NSNumber] created as a float or
 *   double.</item>
 *   <item><strong>dateTime.iso8601</strong>
 *   is an [NSDate] object.</item>
 *   <item><strong>base64</strong>
 *   is an [NSData] object.</item>
 *   <item><strong>array</strong>
 *   is an [NSArray] object.</item>
 *   <item><strong>struct</strong>
 *   is an [NSDictionary] object.</item>
 * </list>
 * <p>If you attempt to use any other type of object in the construction
 * of an XMLRPC document, the [NSObject-description] method of that
 * object will be used to create a string, and the resulting object
 * will be encoded as an XMLRPC <em>string</em> element.
 * </p>
 * <p>In particular, the names of members in a <em>struct</em>
 * must be strings, so if you provide an [NSDictionary] object
 * to represent a <em>struct</em> the keys of the dictionary
 * will be converted to strings where necessary.
 * </p>
 */
@interface GWSXMLRPCCoder : GWSCoder
{
}
/** Take the supplied data and encode it as an XMLRPC timestamp.<br />
 * This uses the timezone currently set in the receiver to determine
 * the time of day encoded.
 */
- (NSString*) encodeDateTimeFrom: (NSDate*)source;

@end

/** <p>The GWSSOAPCCoder class is a concrete subclass of [GWSCoder] which
 * implements coding/decoding for the SOAP protocol.
 * </p>
 * <p>Dictionaries passed to/from the SOAP coder may contain special keys
 * with the <code>GWSSOAP</code> prefix which control the coding rather
 * than specifying values to be coded (this is in addition to the special
 * <code>GWSOrderKey</code> used for ordering fields in a complex type).<br />
 * See the section on constants for a description of what these keys are
 * used for.
 * </p>
 */
@interface GWSSOAPCoder : GWSCoder
{
@protected
  NSString      *_style;        // Not retained
  BOOL          _useLiteral;
}

/** Take the supplied data and return it in the format used for
 * an xsd:dateTime typed element.<br />
 * This uses the timezone currently set in the receiver to determine
 * the time of day encoded and to provide the timezone offset in the
 * encoded string.
 */
- (NSString*) encodeDateTimeFrom: (NSDate*)source;

/** Returns the style of message being used for encoding by the receiver.
 * One of
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleDocument">
 * GWSSOAPBodyEncodingStyleDocument</ref> or
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleRPC">
 * GWSSOAPBodyEncodingStyleRPC</ref> or
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleWrapped">
 * GWSSOAPBodyEncodingStyleWrapped</ref>
 */
- (NSString*) operationStyle;

/** Sets the style for this coder to be
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleDocument">
 * GWSSOAPBodyEncodingStyleDocument</ref> or
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleRPC">
 * GWSSOAPBodyEncodingStyleRPC</ref> or
 * <ref type="constant" id="GWSSOAPBodyEncodingStyleWrapped">
 * GWSSOAPBodyEncodingStyleWrapped</ref>
 */
- (void) setOperationStyle: (NSString*)style;

/** Sets the encoding usage in operation to  be 'literal' (YES)
 * or encoded (NO).
 */
- (void) setUseLiteral: (BOOL)use;

/** Returns whether the encoding usage in operation is 'literal' (YES)
 * or 'encoded' (NO).
 */
- (BOOL) useLiteral;
@end


/** This informal protocol specifies the methods that a coder delegate
 * may implement in order to modify or overriding encoding/decoding of
 * SOAP specific message components.
 */
@interface      NSObject (GWSSOAPCoder)

/** This method is used to inform the delegate of the
 * GWSElement instance being decoded as the SOAP Envelope, Header, Body,
 * Fault or method.<br />
 * The instance to be decoded will contain the children from the
 * document being decoded.<br />
 * The delegate implementation should return the proposed instance
 * (possibly modified) or a different object that it wishes the
 * coder to use.<br />
 * The default implementation returns element.
 */
- (GWSElement*) coder: (GWSSOAPCoder*)coder willDecode: (GWSElement*)element;

/** This method is used to inform the delegate of the proposed
 * GWSElement instance used to encode SOAP Envelope, Header, Body, Fault
 * or method elements.<br />
 * The proposed instance will not have any children at the point
 * where this method is called (they are added later in the
 * encoding process.<br />
 * The delegate implementation should return the proposed instance
 * (possibly modified) or a different object that it wishes the
 * coder to decode instead.<br />
 * The default implementation returns element.<br />
 * NB. A Fault or Body will obviously only be provided where the message
 * contain such an element, and the Header will only be provided where
 * the message has been told to contain headers by use of the
 * GWSSOAPMessageHeadersKey in the parameters dictionary.
 */
- (GWSElement*) coder: (GWSSOAPCoder*)coder willEncode: (GWSElement*)element;
@end

#if	defined(__cplusplus)
}
#endif

#endif

