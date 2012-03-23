//
//  GPGResourceUtil.h
//  Libmacgpg
//
//  Created by Chris Fraire on 3/22/12.
//  Copyright (c) 2012 Chris Fraire. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GPGResourceUtil : NSObject

+ (NSData *)dataForResourceAtPath:(NSString *)path ofType:(NSString *)rtype;

@end
