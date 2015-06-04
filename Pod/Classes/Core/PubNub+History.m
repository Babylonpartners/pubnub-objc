/**
 @author Sergey Mamontov
 @since 4.0
 @copyright © 2009-2015 PubNub, Inc.
 */
#import "PubNub+History.h"
#import "PNRequestParameters.h"
#import "PubNub+CorePrivate.h"
#import "PNResult+Private.h"
#import "PNStatus+Private.h"
#import "PNHelpers.h"


#pragma mark Private interface

@interface PubNub (HistoryPrivate)


#pragma mark - Handlers

/**
 @brief  History request results handling and pre-processing before notify to completion blocks (if
         required at all).
 
 @param result Reference on object which represent server useful response data.
 @param status Reference on object which represent request processing results.
 @param block  History pull processing completion block which pass two arguments: \c result - in
               case of successful request processing \c data field will contain results of history
               request operation; \c status - in case if error occurred during request processing.
 
 @since 4.0
 */
- (void)handleHistoryResult:(PNResult *)result withStatus:(PNStatus *)status
                 completion:(PNHistoryCompletionBlock)block;

#pragma mark -


@end


#pragma mark Interface implementation

@implementation PubNub (History)


#pragma mark - Full history

- (void)historyForChannel:(NSString *)channel withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:nil end:nil withCompletion:block];
}


#pragma mark - History in specified frame

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
           withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:startDate end:endDate limit:100 withCompletion:block];
}

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
                    limit:(NSUInteger)limit withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:startDate end:endDate limit:limit includeTimeToken:NO
             withCompletion:block];
}


#pragma mark - History in frame with extended response

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
         includeTimeToken:(BOOL)shouldIncludeTimeToken withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:startDate end:endDate limit:100
           includeTimeToken:shouldIncludeTimeToken withCompletion:block];
}

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
                    limit:(NSUInteger)limit includeTimeToken:(BOOL)shouldIncludeTimeToken
           withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:startDate end:endDate limit:limit reverse:NO
           includeTimeToken:shouldIncludeTimeToken withCompletion:block];
}

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
                    limit:(NSUInteger)limit reverse:(BOOL)shouldReverseOrder
           withCompletion:(PNHistoryCompletionBlock)block {
    
    [self historyForChannel:channel start:startDate end:endDate limit:limit
                    reverse:shouldReverseOrder includeTimeToken:NO withCompletion:block];
}

- (void)historyForChannel:(NSString *)channel start:(NSNumber *)startDate end:(NSNumber *)endDate
                    limit:(NSUInteger)limit reverse:(BOOL)shouldReverseOrder
         includeTimeToken:(BOOL)shouldIncludeTimeToken withCompletion:(PNHistoryCompletionBlock)block {
    
    // Swap time frame dates if required.
    if ([startDate compare:endDate] == NSOrderedDescending) {
        
        NSNumber *_startDate = startDate;
        startDate = endDate;
        endDate = _startDate;
    }
    // Clamp limit to allowed values.
    limit = MIN(limit, (NSUInteger)100);

    PNRequestParameters *parameters = [PNRequestParameters new];
    [parameters addQueryParameters:@{@"count": @(limit),
                                     @"reverse": (shouldReverseOrder ? @"true" : @"false"),
                                     @"include_token": (shouldIncludeTimeToken ? @"true" : @"false")}];
    if (startDate) {
        
        [parameters addQueryParameter:[startDate stringValue] forFieldName:@"start"];
    }
    if (endDate) {
        
        [parameters addQueryParameter:[endDate stringValue] forFieldName:@"end"];
    }
    if ([channel length]) {
        
        [parameters addPathComponent:[PNString percentEscapedString:channel]
                      forPlaceholder:@"{channel}"];
    }
    
    DDLogAPICall(@"<PubNub> %@ for '%@' channel%@%@ with %@ limit%@.",
                 (shouldReverseOrder ? @"Reversed history" : @"History"), (channel?: @"<error>"),
                 (startDate ? [NSString stringWithFormat:@" from %@", startDate] : @""),
                 (endDate ? [NSString stringWithFormat:@" to %@", endDate] : @""), @(limit),
                 (shouldIncludeTimeToken ? @" (including message time tokens)" : @""));

    PNHistoryCompletionBlock blockCopy = [block copy];
    __weak __typeof(self) weakSelf = self;
    [self processOperation:PNHistoryOperation withParameters:parameters
           completionBlock:^(PNResult *result, PNStatus *status) {

               // Silence static analyzer warnings.
               // Code is aware about this case and at the end will simply call on 'nil'
               // object method. This instance is one of client properties and if client
               // already deallocated there is no need to this object which will be
               // deallocated as well.
               #pragma clang diagnostic push
               #pragma clang diagnostic ignored "-Wreceiver-is-weak"
               #pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
               [weakSelf handleHistoryResult:result withStatus:status completion:blockCopy];
               #pragma clang diagnostic pop
           }];
}


#pragma mark - Handlers

- (void)handleHistoryResult:(PNResult<PNHistoryResult> *)result withStatus:(PNStatus *)status
                 completion:(PNHistoryCompletionBlock)block {

    if (result && ((NSDictionary *)result.data)[@"decryptError"]) {

        status = [PNStatus statusForOperation:PNHistoryOperation
                                     category:PNDecryptionErrorCategory];
        NSMutableDictionary *updatedData = [result.data mutableCopy];
        [updatedData removeObjectForKey:@"decryptError"];
        [status updateData:updatedData];
    }
    [self callBlock:block status:NO withResult:result andStatus:status];
}

#pragma mark -


@end
