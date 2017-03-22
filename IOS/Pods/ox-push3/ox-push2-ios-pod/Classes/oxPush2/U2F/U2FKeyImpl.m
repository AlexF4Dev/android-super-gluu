//
//  U2FKeyImpl.m
//  oxPush2-IOS
//
//  Created by Nazar Yavornytskyy on 2/12/16.
//  Copyright © 2016 Nazar Yavornytskyy. All rights reserved.
//

#import "U2FKeyImpl.h"
#import "GMEllipticCurveCrypto.h"
#import "GMEllipticCurveCrypto+hash.h"
#import "TokenEntity.h"
#import <NSHash/NSString+NSHash.h>
#import <NSHash/NSData+NSHash.h>
#import "Base64.h"
#import "Constants.h"
#import "DataStoreManager.h"
#import "NSString+URLEncode.h"
#import "AuthenticateResponse.h"
#import "AuthenticateRequest.h"
#import "UserPresenceVerifier.h"

#define INIT_SECURE_CLICK_NOTIFICATION @"INIT_SECURE_CLICK_NOTIFICATION"

Byte REGISTRATION_RESERVED_BYTE_VALUE = 0x05;
int keyHandleLength = 64;

@implementation U2FKeyImpl {
    SecureClickCompletionHandler secureClickHandler;
    SecureClickAuthCompletionHandler secureClickAuthHandler;
    GMEllipticCurveCrypto *secureClickCrypto;
    NSData* secureClickUserPublicKey;
    NSMutableData* secureClickKeyHandle;
    int countAuth;
}

-(id)init{
    codec = [[RawMessageCodec alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(waitForSecureClickNotification:) name:@"didUpdateValueForCharacteristic" object:nil];
    return self;
}

-(void) registerRequest:(EnrollmentRequest*)enrollmentRequest isDecline:(BOOL)isDecline isSecureClick:(BOOL)isSecureClick callback:(SecureClickCompletionHandler)handler {
    
    NSString* application = [enrollmentRequest application];
    NSString* challenge = [enrollmentRequest challenge];
    
    //Generate a new ECC key pair
    GMEllipticCurveCrypto *crypto = [GMEllipticCurveCrypto generateKeyPairForCurve:
                                     GMEllipticCurveSecp256r1];
    
    NSData* userPublicKey = crypto.publicKey;
    NSMutableData* keyHandle = [[NSMutableData alloc] init];
    for (int i = 0; i < keyHandleLength; i ++){
        int randomByte = arc4random() % 256;
        [keyHandle appendBytes:&randomByte length:1];
    }
    if (!isDecline){
        //Save new keys into database
        TokenEntity* newTokenEntity = [[TokenEntity alloc] init];
        NSString* keyID = application;
        newTokenEntity->ID = keyID;
        newTokenEntity->application = application;
        newTokenEntity->issuer = [enrollmentRequest issuer];
        newTokenEntity->keyHandle = [keyHandle base64EncodedString];
        newTokenEntity->publicKey = crypto.publicKeyBase64;
        newTokenEntity->privateKey = crypto.privateKeyBase64;
        newTokenEntity->userName = [UserLoginInfo sharedInstance]->userName;
        newTokenEntity->pairingTime = [UserLoginInfo sharedInstance]->created;
        newTokenEntity->authenticationMode = [UserLoginInfo sharedInstance]->authenticationMode;
        newTokenEntity->authenticationType = [UserLoginInfo sharedInstance]->authenticationType;
        [[DataStoreManager sharedInstance] saveTokenEntity:newTokenEntity];
    }
    
    NSData* applicationSha256 = [[application SHA256] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* challengeSha256 = [[challenge SHA256] dataUsingEncoding:NSUTF8StringEncoding];
    
    
    NSMutableData* signedData = [[NSMutableData alloc] init];
    //if we're using SecureClick, then responce we'll get from DP SC device
    if (isSecureClick) {
        NSData* applicationSha256Data = [application SHA256Data];
        NSData* challengeSha256Data = [challenge SHA256Data];
        [signedData appendData:applicationSha256Data];
        [signedData appendData:challengeSha256Data];
        [self initBLE:signedData crypto:crypto userPublicKey:userPublicKey keyHandle:keyHandle callback:handler];
    } else {
        signedData = [codec encodeEnrollementSignedBytes:REGISTRATION_RESERVED_BYTE_VALUE applicationSha256:applicationSha256 challengeSha256:challengeSha256 keyHandle:keyHandle userPublicKey:userPublicKey];
        EnrollmentResponse* response = [self makeEnrollmentResponse:signedData crypto:crypto userPublicKey:userPublicKey keyHandle:keyHandle];
        handler(response ,nil);
    }
}

-(void)autenticate:(AuthenticateRequest*)request isSecureClick:(BOOL)isSecureClick callback:(SecureClickAuthCompletionHandler)handler{
    
    //    NSData* control = [request control];
    NSString* application = [request application];
    NSString* challenge = [request challenge];
    //    NSData* keyHandle = [request keyHandle];
    TokenEntity* tokenEntity = nil;
    NSArray* tokenEntities = [[DataStoreManager sharedInstance] getTokenEntitiesByID:application];
    if ([tokenEntities count] > 0){
        tokenEntity = [tokenEntities objectAtIndex:0];
    } else {
        //No token(s) found
    }
    if (tokenEntity != nil){
        
    } else {
        //There is no keyPair
    }
    int count = [[DataStoreManager sharedInstance] incrementCountForToken:tokenEntity];
    UserPresenceVerifier* userPres = [[UserPresenceVerifier alloc] init];
    NSData* userPresence = [userPres verifyUserPresence];
    NSData* applicationSha256 = [[application SHA256] dataUsingEncoding:NSUTF8StringEncoding];
    NSData* challengeSha256 = [[challenge SHA256] dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableData* signedData = [[NSMutableData alloc] init];
    //if we're using SecureClick, then responce we'll get from DP SC device
    if (isSecureClick) {
        //Make authentication message for VASCO SecureClick device 
        NSData* applicationSha256Data = [application SHA256Data];
        NSData* challengeSha256Data = [challenge SHA256Data];
        signedData = [codec makeAuthenticateMessage:applicationSha256Data challengeSha256:challengeSha256Data keyHandle:request.keyHandle];
        [self initBLEForAuthentication:signedData count:count callback:handler];
    } else {
        
        signedData = [codec encodeAuthenticateSignedBytes:applicationSha256 userPresence:userPresence counter:count challengeSha256:challengeSha256];
        
        GMEllipticCurveCrypto* crypto2 = [GMEllipticCurveCrypto generateKeyPairForCurve:
                                          GMEllipticCurveSecp256r1];
        
        NSData *signature = [crypto2 hashSHA256AndSignDataEncoded:signedData];
        
        AuthenticateResponse* response = [[AuthenticateResponse alloc] initWithUserPresence:userPresence counter:count signature:signature];
        handler(response ,nil);
    }
}

-(EnrollmentResponse*)makeEnrollmentResponse:(NSData*)signedData crypto:(GMEllipticCurveCrypto*)crypto userPublicKey:(NSData*) userPublicKey keyHandle:(NSData*) keyHandle{
    NSData *signature = [crypto hashSHA256AndSignDataEncoded:signedData];
    
    NSData* sertificate = [VENDOR_CERTIFICATE_CERT dataFromHexString];
    
    EnrollmentResponse* response = [[EnrollmentResponse alloc] initWithUserPublicKey:userPublicKey keyHandle:keyHandle attestationCertificate:sertificate signature:signature];
    
    return response;
}

-(void)initBLE:(NSData*)valueData crypto:(GMEllipticCurveCrypto*)crypto userPublicKey:(NSData*) userPublicKey keyHandle:(NSData*)keyHandle callback:(SecureClickCompletionHandler)handler{
    
    secureClickHandler = handler;
    secureClickCrypto = crypto;
    secureClickUserPublicKey = userPublicKey;
    secureClickKeyHandle = keyHandle;
    [[NSNotificationCenter defaultCenter] postNotificationName:INIT_SECURE_CLICK_NOTIFICATION object:valueData];
}

-(void)initBLEForAuthentication:(NSData*)valueData count:(int)count callback:(SecureClickAuthCompletionHandler)handler{
    
    secureClickAuthHandler = handler;
    countAuth = count;
    [[NSNotificationCenter defaultCenter] postNotificationName:INIT_SECURE_CLICK_NOTIFICATION object:valueData];
}

-(void)waitForSecureClickNotification:(NSNotification*)notification{
    NSDictionary* dic = notification.object;
    NSData* responseData = [dic objectForKey:@"responseData"];
    
    BOOL isEnroll = [dic objectForKey:@"isEnroll"];
    
    if (responseData != nil){
        if (isEnroll){
            EnrollmentResponse* response = [self makeEnrollmentResponse:responseData crypto:secureClickCrypto userPublicKey:secureClickUserPublicKey keyHandle:secureClickKeyHandle];
            secureClickHandler(response, nil);
        } else {
            GMEllipticCurveCrypto* crypto = [GMEllipticCurveCrypto generateKeyPairForCurve:
                                             GMEllipticCurveSecp256r1];
            
            NSData *signature = [crypto hashSHA256AndSignDataEncoded:responseData];
            UserPresenceVerifier* userPres = [[UserPresenceVerifier alloc] init];
            NSData* userPresence = [userPres verifyUserPresence];
            AuthenticateResponse* response = [[AuthenticateResponse alloc] initWithUserPresence:userPresence counter:countAuth signature:signature];
            secureClickAuthHandler(response, nil);
        }
    }
}

@end
