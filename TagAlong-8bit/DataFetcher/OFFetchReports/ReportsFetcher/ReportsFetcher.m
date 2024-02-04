//
//  OpenHaystack – Tracking personal Bluetooth devices via Apple's Find My network
//
//  Copyright © 2021 Secure Mobile Networking Lab (SEEMOO)
//  Copyright © 2021 The Open Wireless Link Project
//
//  SPDX-License-Identifier: AGPL-3.0-only
//

#import "ReportsFetcher.h"
#import <Security/Security.h>

#import <Accounts/Accounts.h>

#import "OFFetchReports-Swift.h"

@implementation ReportsFetcher

- (NSData * _Nullable) fetchSearchpartyToken {
    NSDictionary *query = @{
        (NSString*) kSecClass : (NSString*) kSecClassGenericPassword,
        (NSString*) kSecAttrService: @"com.apple.account.AppleAccount.search-party-token",
        (NSString*) kSecMatchLimit: (id) kSecMatchLimitOne,
        (NSString*) kSecReturnData: @true
    };
    
    CFTypeRef item;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, &item);
    
    if (status == errSecSuccess) {
        NSData *securityToken = (__bridge NSData *)(item);
        
        NSLog(@"Fetched token %@", [[NSString alloc] initWithData:securityToken encoding:NSUTF8StringEncoding]);
        
        if (securityToken.length == 0) {
            return [self fetchSearchpartyTokenFromAccounts];
        }
        
        return securityToken;
    }

    
    return [self fetchSearchpartyTokenFromAccounts];;
}

- (NSData * _Nullable) fetchSearchpartyTokenFromAccounts {
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:@"com.apple.account.AppleAccount"];
    
    NSArray *appleAccounts = [accountStore accountsWithAccountType:accountType];
    
    if (appleAccounts == nil && appleAccounts.count > 0) {return nil;}
    
    ACAccount *iCloudAccount = appleAccounts[0];
    ACAccountCredential *iCloudCredentials = iCloudAccount.credential;
    
    if ([iCloudCredentials respondsToSelector:NSSelectorFromString(@"credentialItems")]) {
        NSDictionary* credentialItems = [iCloudCredentials performSelector:NSSelectorFromString(@"credentialItems")];
        NSString *searchPartyToken = credentialItems[@"search-party-token"];
        NSData *tokenData = [searchPartyToken dataUsingEncoding:NSASCIIStringEncoding];
        return tokenData;
    }

    return nil;
}

- (NSString *) fetchAppleAccountId {
    NSDictionary *query = @{
        (NSString*) kSecClass : (NSString*) kSecClassGenericPassword,
        (NSString*) kSecAttrService: @"iCloud",
        (NSString*) kSecMatchLimit: (id) kSecMatchLimitOne,
        (NSString*) kSecReturnAttributes: @true
    };
    
    CFTypeRef item;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, &item);
    
    if (status == errSecSuccess) {
        NSDictionary *itemDict = (__bridge NSDictionary *)(item);
        
        NSString *accountId = itemDict[(NSString *) kSecAttrAccount];
         
        return accountId;
    }
    
    return nil;
}

- (NSString *) basicAuthForAppleID: (NSString *) appleId andToken: (NSData*) token {
    NSString * tokenString = [[NSString alloc] initWithData:token encoding:NSUTF8StringEncoding];
    NSString * authText = [NSString stringWithFormat:@"%@:%@", appleId, tokenString];
    NSString * base64Auth = [[authText dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    NSString *auth = [NSString stringWithFormat:@"Basic %@", base64Auth];
    
    return auth;
}


- (NSDictionary *)anisetteDataDictionary {
#if AUTHKIT
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"https://gateway.icloud.com/acsnservice/fetch"]];
    [req setHTTPMethod:@"POST"];

    AKAppleIDSession *session = [[NSClassFromString(@"AKAppleIDSession") alloc] initWithIdentifier:@"com.apple.gs.xcode.auth"];
    NSDictionary *appleHeadersDict = [session appleIDHeadersForRequest:req];

    return appleHeadersDict;
#endif

    return [NSDictionary new];
}

- (void)fetchAnisetteData:(void (^)(NSDictionary *_Nullable))completion {
    AnisetteDataManager *anisetteManager = [[AnisetteDataManager alloc] init];
    
    [anisetteManager requestAnisetteDataObjc:^(NSDictionary *_Nullable dict) {
        completion(dict);
    }];
}

- (void)queryForHashes:(NSArray *)publicKeys
             startDate:(NSDate *)date
             duration:(double)duration
      searchPartyToken:(NSData *)searchPartyToken
           completion:(void (^)(NSData * _Nullable))completion {
    
    // Calculate the timestamps for the defined duration
    long long startDateValue = [date timeIntervalSince1970] * 1000;
    long long endDateValue = ([date timeIntervalSince1970] + duration) * 1000.0;
    
    // NSLog(@"Requesting data for %@", publicKeys);
    NSDictionary *query = @{
        @"search": @[
            @{
                @"endDate": [NSString stringWithFormat:@"%lli", endDateValue],
                @"ids": publicKeys,
                @"startDate": [NSString stringWithFormat:@"%lli", startDateValue]
            }
        ]
    };
    
    NSData *httpBody = [NSJSONSerialization dataWithJSONObject:query options:0 error:nil];
    
    //NSLog(@"Query: %@", query);
    
    NSString *authKey = @"authorization";
    NSData *securityToken = searchPartyToken;
    NSString *appleId = [self fetchAppleAccountId];
    NSString *authValue = [self basicAuthForAppleID:appleId andToken:securityToken];
    
    [self fetchAnisetteData:^(NSDictionary * _Nullable dict) {
        if (dict == nil) {
            completion(nil);
            return;
        }
        
        NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:[[NSURL alloc] initWithString:@"https://gateway.icloud.com/acsnservice/fetch"]];
        
        [req setHTTPMethod:@"POST"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [req setValue:authValue forHTTPHeaderField:authKey];
        
        NSDictionary *appleHeadersDict = dict;
        for (id key in appleHeadersDict) {
            [req setValue:[appleHeadersDict objectForKey:key] forHTTPHeaderField:key];
        }
        
        NSLog(@"Headers:\n%@", req.allHTTPHeaderFields);
        [req setHTTPBody:httpBody];
        
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error during request: %@", error);
                completion(nil);
            } else {
                
                completion(data);
            }
        }];
        [task resume];
    }];
}


@end

