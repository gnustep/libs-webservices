/** 
   Copyright (C) 2008 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	September 2008
   
   This file is part of the WebServices package.

   This is free software; you can redistribute it and/or
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

#include	<Foundation/Foundation.h>
#include	"GWSPrivate.h"

int
main()
{
  NSAutoreleasePool     *pool;
  NSUserDefaults	*defs;
  GWSCoder              *coder;
  GWSService		*service;
  GWSDocument   	*document;
  NSData                *xml;
  NSString              *method;
  NSMutableArray        *order;
  NSMutableDictionary   *params;
  NSMutableArray        *norder;
  NSMutableDictionary   *nparams;
  NSDictionary          *result;

  pool = [NSAutoreleasePool new];

  defs = [NSUserDefaults standardUserDefaults];
  [defs registerDefaults:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"80", @"Port",
      nil]
    ];


  document = [[GWSDocument alloc] initWithContentsOfFile: @"SMS.wsdl"];
  xml = [document data];
  NSLog(@"Document:\n%*.*s", [xml length], [xml length], [xml bytes]);
  [document release];

  document = [[GWSDocument alloc] initWithContentsOfFile: @"Enterprise.wsdl"];
  xml = [document data];
  NSLog(@"Document:\n%*.*s", [xml length], [xml length], [xml bytes]);
  [document release];



  // [[NSRunLoop currentRunLoop] run];

  coder = [GWSXMLRPCCoder new];

  /* Test encoding and decoding of an XMLRPC request.
   */
  params = [NSMutableDictionary dictionaryWithCapacity: 8];
  order = [NSMutableArray arrayWithCapacity: 8];
  [params setObject: @"hello" forKey: @"string1"];
  [order addObject: @"string1"];
  [params setObject: [NSDictionary dictionaryWithObjectsAndKeys:
    @"obj1", @"key1",
    nil] forKey: @"dict1"];
  [order addObject: @"dict1"];
  method = @"test";
  fprintf(stdout, "Request encode/decode ");
  xml = [coder buildRequest: method
                 parameters: params
                      order: order];
  result = [coder parseMessage: xml];
  norder = [result objectForKey: GWSOrderKey];
  nparams = [result objectForKey: GWSParametersKey];
  if (NO == [method isEqual: [result objectForKey: GWSMethodKey]])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Method does not match ... %@", result);
    }
  else if ([order count] != [norder count])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Counts of order array do not match ... %@", result);
    }
  else if ([params count] != [nparams count])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Counts of params do not match ... %@", result);
    }
  else
    {
      unsigned  c = [order count];
      BOOL      fail = NO;

      while (c-- > 0)
        {
          id    o = [params objectForKey: [order objectAtIndex: c]];
          id    n = [nparams objectForKey: [norder objectAtIndex: c]];

          if (NO == [o isEqual: n])
            {
              if (NO == fail)
                {
                  fprintf(stdout, "FAIL\n");
                  fail = YES;
                }
              NSLog(@"Parameter %u does not match", c);
            }
        }
      if (YES == fail)
        {
          NSLog(@"Parameters do not match ... %@", result);
        }
      else
        {
          fprintf(stdout, "PASS\n");
        }
    }


  [coder release];



  coder = [GWSSOAPCoder new];

  /* Test encoding and decoding of a SOAP request.
   */
  params = [NSMutableDictionary dictionaryWithCapacity: 8];
  order = [NSMutableArray arrayWithCapacity: 8];
  [params setObject: @"hello<" forKey: @"string1"];
  [order addObject: @"string1"];
  method = @"test";
  fprintf(stdout, "Request encode/decode ");
  [(GWSSOAPCoder*)coder setOperationStyle: GWSSOAPBodyEncodingStyleRPC];
  xml = [coder buildRequest: method
                 parameters: params
                      order: order];
  result = [coder parseMessage: xml];
  norder = [result objectForKey: GWSOrderKey];
  nparams = [result objectForKey: GWSParametersKey];
  if (NO == [method isEqual: [result objectForKey: GWSMethodKey]])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Method does not match ... %@", result);
    }
  else if ([order count] != [norder count])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Counts of order array do not match ... %@", result);
    }
  else if ([params count] != [nparams count])
    {
      fprintf(stdout, "FAIL\n");
      NSLog(@"Counts of params do not match ... %@", result);
    }
  else
    {
      unsigned  c = [order count];
      BOOL      fail = NO;

      while (c-- > 0)
        {
          id    o = [params objectForKey: [order objectAtIndex: c]];
          id    n = [nparams objectForKey: [norder objectAtIndex: c]];

          if (NO == [o isEqual: n])
            {
              if (NO == fail)
                {
                  fprintf(stdout, "FAIL\n");
                  fail = YES;
                }
              NSLog(@"Parameter %u does not match", c);
            }
        }
      if (YES == fail)
        {
          NSLog(@"Parameters do not match ... %@", result);
        }
      else
        {
          fprintf(stdout, "PASS\n");
        }
    }


  fprintf(stdout, "Expect this to produce an error ... it tries a request"
    " on the local web server:\n");
  service = [GWSService new]; 
  [service setURL: @"http://localhost/"];
  [service setCoder: coder];
  result = [service invokeMethod: method
                      parameters: params
                           order: order
                         timeout: 30];
  fprintf(stdout, "Result: %s\n", [[result description] cString]);
  [service release];

  [coder release];

  [pool release];
  return 0;
}

