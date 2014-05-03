/* GPGTypesRW.h created by Lukas Pitschl (@lukele) on Sun 21-Jul-2014 */

/*
 * Copyright (c) 2000-2014, GPGTools Team <team@gpgtools.org>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of GPGTools Team nor the names of Libmacgpg
 *       contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE GPGTools Team ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE GPGTools Project Team BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Libmacgpg/GPGKey.h>
#import <Libmacgpg/GPGUserID.h>
#import <Libmacgpg/GPGUserIDSignature.h>
#import <Libmacgpg/GPGSignature.h>


@interface GPGKey ()

@property (copy, readwrite) NSString *keyID;
@property (copy, readwrite) NSString *fingerprint;
@property (copy, readwrite) NSString *cardID;
@property (copy, readwrite) NSDate *creationDate;
@property (copy, readwrite) NSDate *expirationDate;
@property (assign, readwrite) unsigned int length;
@property (assign, readwrite) GPGPublicKeyAlgorithm algorithm;
@property (assign, readwrite) GPGValidity ownerTrust;
@property (assign, readwrite) GPGValidity validity;

@property (copy, readwrite) NSArray *subkeys;
@property (copy, readwrite) NSArray *userIDs;
@property (copy, readwrite) NSArray *signatures;

@property (assign, readwrite) GPGKey *primaryKey;
@property (assign, readwrite) GPGUserID *primaryUserID;

@property (assign, readwrite) BOOL secret;

@property (assign, readwrite) BOOL canSign;
@property (assign, readwrite) BOOL canEncrypt;
@property (assign, readwrite) BOOL canCertify;
@property (assign, readwrite) BOOL canAuthenticate;
@property (assign, readwrite) BOOL canAnySign;
@property (assign, readwrite) BOOL canAnyEncrypt;
@property (assign, readwrite) BOOL canAnyCertify;
@property (assign, readwrite) BOOL canAnyAuthenticate;

@end

@interface GPGUserID ()

@property (copy, readwrite) NSString *userIDDescription;
@property (copy, readwrite) NSString *name;
@property (copy, readwrite) NSString *email;
@property (copy, readwrite) NSString *comment;
@property (copy, readwrite) NSString *hashID;
@property (copy, readwrite) NSImage *image;
@property (copy, readwrite) NSDate *creationDate;
@property (copy, readwrite) NSDate *expirationDate;
@property (assign, readwrite) GPGValidity validity;

@property (copy, readwrite) NSArray *signatures;
@property (assign, readwrite) GPGKey *primaryKey;

@end

@interface GPGUserIDSignature ()

@property (copy, readwrite) NSString *keyID;
@property (assign, readwrite) GPGPublicKeyAlgorithm algorithm;
@property (copy, readwrite) NSDate *creationDate;
@property (copy, readwrite) NSDate *expirationDate;
@property (copy, readwrite) NSString *reason;
@property (assign, readwrite) int signatureClass;
@property (assign, readwrite) BOOL revocation;
@property (assign, readwrite) BOOL local;

@property (assign, readwrite) GPGKey *primaryKey;

@end

@interface GPGSignature ()

@property (assign, readwrite) GPGValidity trust;
@property (assign, readwrite) GPGErrorCode status;
@property (copy, readwrite) NSString *fingerprint;
@property (copy, readwrite) NSDate *creationDate;
@property (assign, readwrite) int signatureClass;
@property (copy, readwrite) NSDate *expirationDate;
@property (assign, readwrite) int version;
@property (assign, readwrite) GPGPublicKeyAlgorithm publicKeyAlgorithm;
@property (assign, readwrite) GPGHashAlgorithm hashAlgorithm;

@end

