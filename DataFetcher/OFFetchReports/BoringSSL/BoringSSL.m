//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

#import "BoringSSL.h"

#include <CNIOBoringSSL.h>
#include <CNIOBoringSSL_ec.h>
#include <CNIOBoringSSL_ec_key.h>
#include <CNIOBoringSSL_evp.h>
#include <CNIOBoringSSL_hkdf.h>
#include <CNIOBoringSSL_pkcs7.h>

@implementation BoringSSL

+ (NSData * _Nullable) deriveSharedKeyFromPrivateKey: (NSData *) privateKey andEphemeralKey: (NSData*) ephemeralKeyPoint {
    
    NSLog(@"Private key %@", [privateKey base64EncodedStringWithOptions:0]);
    NSLog(@"Ephemeral key %@", [ephemeralKeyPoint base64EncodedStringWithOptions:0]);
    
    EC_GROUP *curve = EC_GROUP_new_by_curve_name(NID_secp224r1);
    
    EC_KEY *key = [self deriveEllipticCurvePrivateKey:privateKey group:curve];
    
    const EC_POINT *genPubKey = EC_KEY_get0_public_key(key);
    [self printPoint:genPubKey withGroup:curve];
    
    EC_POINT *publicKey = EC_POINT_new(curve);
    size_t load_success = EC_POINT_oct2point(curve, publicKey, ephemeralKeyPoint.bytes, ephemeralKeyPoint.length, NULL);
    if (load_success == 0) {
        NSLog(@"Failed loading public key!");
        return nil; 
    }
    
    NSMutableData *sharedKey = [[NSMutableData alloc] initWithLength:28];
    
    int res = ECDH_compute_key(sharedKey.mutableBytes, sharedKey.length, publicKey, key, nil);
    
    if (res < 1) {
        NSLog(@"Failed with error: %d", res);
        BIO *bio = BIO_new(BIO_s_mem());
        ERR_print_errors(bio);
        char *buf;
        size_t len = BIO_get_mem_data(bio, &buf);
        NSLog(@"Generating shared key failed %s", buf); 
        BIO_free(bio);
    }
    
    NSLog(@"Shared key: %@", [sharedKey base64EncodedStringWithOptions:0]);
    
    return sharedKey;
}

+ (EC_POINT * _Nullable) loadEllipticCurvePublicBytesWith: (EC_GROUP *) group andPointBytes: (NSData *) pointBytes {
    
    EC_POINT* point = EC_POINT_new(group);
    
    //Create big number context
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    
    //Public key will be stored in point
    int res = EC_POINT_oct2point(group, point, pointBytes.bytes, pointBytes.length, ctx);
    [self printPoint:point withGroup:group];
    
    //Free the big numbers
    BN_CTX_free(ctx);
    
    if (res != 1) {
        //Failed
        return nil;
    }
    
    return point;
}


/// Get the private key on the curve from the private key bytes
/// @param privateKeyData NSData representing the private key
/// @param group The EC group representing the curve to use
+ (EC_KEY * _Nullable) deriveEllipticCurvePrivateKey: (NSData *)privateKeyData group: (EC_GROUP *) group {
    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp224r1);
    EC_POINT *point = EC_POINT_new(group);
    
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    
    
    BIGNUM *privateKeyNum = BN_bin2bn(privateKeyData.bytes, privateKeyData.length, nil);
    
    int res = EC_POINT_mul(group, point, privateKeyNum, nil, nil, ctx);
    if (res != 1) {
        NSLog(@"Failed");
        return nil;
    }

    res = EC_KEY_set_public_key(key, point);
    if (res != 1) {
        NSLog(@"Failed");
        return nil;
    }
    
    privateKeyNum = BN_bin2bn(privateKeyData.bytes, privateKeyData.length, nil);
    EC_KEY_set_private_key(key, privateKeyNum);
    
    
    //Free the big numbers
    BN_CTX_free(ctx);
    
    return key;
}


/// Derive a public key from a given private key
/// @param privateKeyData an EC private key on the P-224 curve
+ (NSData * _Nullable) derivePublicKeyFromPrivateKey: (NSData*) privateKeyData {
    EC_GROUP *curve = EC_GROUP_new_by_curve_name(NID_secp224r1);
    EC_KEY *key = [self deriveEllipticCurvePrivateKey:privateKeyData group:curve];
    
    const EC_POINT *publicKey = EC_KEY_get0_public_key(key);
    
    size_t keySize = 28 + 1;
    NSMutableData *publicKeyBytes = [[NSMutableData alloc] initWithLength:keySize];
    
    size_t size = EC_POINT_point2oct(curve, publicKey, POINT_CONVERSION_COMPRESSED, publicKeyBytes.mutableBytes, keySize, NULL);
    
    if (size == 0) {
        return nil;
    }
    
    return publicKeyBytes;
}

+ (NSData *_Nullable)derivePublicKeyAndValidate:(NSData *)privateKeyData {
   EC_GROUP *curve = EC_GROUP_new_by_curve_name(NID_secp224r1);

    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp224r1);
    EC_POINT *point = EC_POINT_new(curve);
   
    NSData * pub_key_bytes = [self derivePublicKeyFromPrivateKey: privateKeyData];
    NSData * pub_key_bytes_no_y = [NSData dataWithBytesNoCopy:(char *)[pub_key_bytes bytes] + 1
                                         length:28
                                   freeWhenDone:NO];

    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);

    NSLog(@"converting");
    BIGNUM *privateKeyNum = BN_bin2bn(privateKeyData.bytes, privateKeyData.length, nil);
    BIGNUM *pubKeyX = BN_bin2bn(pub_key_bytes_no_y.bytes, pub_key_bytes_no_y.length, nil);

    NSLog(@"set_coords");
    int ret = EC_POINT_set_compressed_coordinates_GFp(curve, point, pubKeyX, 1, nil);
    
    //EC_KEY_set_private_key(key, privateKeyNum);
    NSLog(@"ret: %d", ret);

    if(!EC_POINT_is_on_curve(curve, point, NULL)) {
         return nil; // TODO: FIX, currently always returns 0
    }

    size_t keySize = 28 + 1;
    NSMutableData *publicKeyBytes = [[NSMutableData alloc] initWithLength:keySize];

    size_t size = EC_POINT_point2oct(curve, point, POINT_CONVERSION_COMPRESSED, publicKeyBytes.mutableBytes, keySize, NULL);

    if (size == 0) {
        return nil;
    }

    return publicKeyBytes;
}

+ (int)isPublicKeyValid:(NSData *)publicKeyData {
   EC_GROUP *curve = EC_GROUP_new_by_curve_name(NID_secp224r1);

    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp224r1);
    EC_POINT *point = EC_POINT_new(curve);
   
    BIGNUM *publicKeyX = BN_new();
    BN_bin2bn(publicKeyData.bytes, publicKeyData.length, publicKeyX);

    return EC_POINT_set_compressed_coordinates_GFp(curve, point, publicKeyX, 0, nil);
    //printf(EC_POINT_is_on_curve(curve, point, NULL));
    //BN_free(publicKeyX);
    //EC_GROUP_free(curve_group);
    //if(!EC_POINT_is_on_curve(curve, point, NULL)) {
    //     //EC_POINT_free(point);
    //     return 0;
    //}

    //EC_POINT_free(point);
    //return 1;
}

+ (NSData * _Nullable)generateNewPrivateKey {
    EC_KEY *key = EC_KEY_new_by_curve_name(NID_secp224r1);
    if (EC_KEY_generate_key_fips(key) == 0) {
        return nil;
    }
    
    const BIGNUM *privateKey = EC_KEY_get0_private_key(key);
    size_t keySize = BN_num_bytes(privateKey);
    //Convert to bytes
    NSMutableData *privateKeyBytes = [[NSMutableData alloc] initWithLength:keySize];
    
    
    size_t size = BN_bn2bin(privateKey, privateKeyBytes.mutableBytes);
    
    if (size == 0) {
        return nil;
    }
    
    return privateKeyBytes;
}

+ (void) printPoint: (const EC_POINT *)point withGroup:(EC_GROUP *)group {
    NSMutableData *pointData = [[NSMutableData alloc] initWithLength:256];
    
    size_t len = pointData.length;
    BN_CTX *ctx = BN_CTX_new();
    BN_CTX_start(ctx);
    size_t res = EC_POINT_point2oct(group, point, POINT_CONVERSION_UNCOMPRESSED, pointData.mutableBytes, len, ctx);
    //Free the big numbers
    BN_CTX_free(ctx);
    
    NSData *written = [[NSData alloc] initWithBytes:pointData.bytes length:res];
        
    NSLog(@"Point data is: %@", [written base64EncodedStringWithOptions:0]);
}

@end
