#import <assert.h>
#import <dispatch/dispatch.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSException.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSOperation.h>
#import <Foundation/NSPointerArray.h>
#import <objc/runtime.h>
#import "NSMethodSignatureForBlock.m"
#import "CPPromise.h"
#import <string.h>
#import "fwd.h"

#define IsPromise(o) ([o isKindOfClass:[CPPromise class]])
#define IsError(o) ([o isKindOfClass:[NSError class]])
#define PMKE(txt) [NSException exceptionWithName:@"PromiseKit" reason:@"PromiseKit: " txt userInfo:nil]

#ifndef PMKLog
#define PMKLog NSLog
#endif

NSString* const CorePromiseErrorDomain = @"com.bedroomcode.core.promise.error.domain";

static const id PMKNull = @"PMKNull";



@interface PMKArray : NSObject
@end



static inline NSError *NSErrorFromNil() {
    PMKLog(@"PromiseKit: Warning: Promise rejected with nil");
    return [NSError errorWithDomain:PMKErrorDomain code:PMKInvalidUsageError userInfo:nil];
}

static inline NSError *NSErrorFromException(id exception) {
    if (!exception)
        return NSErrorFromNil();

    id userInfo = @{
        PMKUnderlyingExceptionKey: exception,
        NSLocalizedDescriptionKey: [exception isKindOfClass:[NSException class]]
            ? [exception reason]
            : [exception description]
    };
    return [NSError errorWithDomain:PMKErrorDomain code:PMKUnhandledExceptionError userInfo:userInfo];
}



@interface PMKError : NSObject @end @implementation PMKError {
    NSError *error;
    BOOL consumed;
}

static void *PMKErrorAssociatedObject = &PMKErrorAssociatedObject;

- (void)dealloc {
    if (!consumed && PMKUnhandledErrorHandler)
        PMKUnhandledErrorHandler(error);
}

+ (void)consume:(NSError *)error {
    PMKError *pmke = objc_getAssociatedObject(error, PMKErrorAssociatedObject);
    pmke->consumed = YES;    
}

+ (void)unconsume:(NSError *)error {
    PMKError *pmke = objc_getAssociatedObject(error, PMKErrorAssociatedObject);

    if (!pmke) {
        pmke = [PMKError new];

        // we take a copy to avoid a retain cycle. A weak ref
        // is no good because then the error is deallocated
        // before we can call PMKUnhandledErrorHandler()
        pmke->error = [error copy];

        // this is how we know when the error is deallocated
        // because we will be deallocated at the same time
        objc_setAssociatedObject(error, PMKErrorAssociatedObject, pmke, OBJC_ASSOCIATION_RETAIN_NONATOMIC);        
    }
    else
        pmke->consumed = NO;
}

@end

void (^PMKUnhandledErrorHandler)(id) = ^(NSError *error){
    PMKLog(@"PromiseKit: Unhandled error: %@", error);
};



// deprecated
NSString const*const PMKThrown = PMKUnderlyingExceptionKey;



/**
 `then` and `catch` are method-signature tolerant, this function calls
 the block correctly and normalizes the return value to `id`.
 */
id pmk_safely_call_block(id frock, id result) {
    assert(frock);

    if (result == PMKNull)
        result = nil;

    @try {
        NSMethodSignature *sig = NSMethodSignatureForBlock(frock);
        const NSUInteger nargs = sig.numberOfArguments;
        const char rtype = sig.methodReturnType[0];

        #define call_block_with_rtype(type) ({^type{ \
            switch (nargs) { \
                case 1: \
                    return ((type(^)(void))frock)(); \
                case 2: { \
                    const id arg = [result class] == [PMKArray class] ? result[0] : result; \
                    return ((type(^)(id))frock)(arg); \
                } \
                case 3: { \
                    type (^block)(id, id) = frock; \
                    return [result class] == [PMKArray class] \
                        ? block(result[0], result[1]) \
                        : block(result, nil); \
                } \
                case 4: { \
                    type (^block)(id, id, id) = frock; \
                    return [result class] == [PMKArray class] \
                        ? block(result[0], result[1], result[2]) \
                        : block(result, nil, nil); \
                } \
                default: \
                    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"PromiseKit: The provided block’s argument count is unsupported." userInfo:nil]; \
            }}();})

        switch (rtype) {
            case 'v':
                call_block_with_rtype(void);
                return PMKNull;
            case '@':
                return call_block_with_rtype(id) ?: PMKNull;
            case '*': {
                char *str = call_block_with_rtype(char *);
                return str ? @(str) : PMKNull;
            }
            case 'c': return @(call_block_with_rtype(char));
            case 'i': return @(call_block_with_rtype(int));
            case 's': return @(call_block_with_rtype(short));
            case 'l': return @(call_block_with_rtype(long));
            case 'q': return @(call_block_with_rtype(long long));
            case 'C': return @(call_block_with_rtype(unsigned char));
            case 'I': return @(call_block_with_rtype(unsigned int));
            case 'S': return @(call_block_with_rtype(unsigned short));
            case 'L': return @(call_block_with_rtype(unsigned long));
            case 'Q': return @(call_block_with_rtype(unsigned long long));
            case 'f': return @(call_block_with_rtype(float));
            case 'd': return @(call_block_with_rtype(double));
            case 'B': return @(call_block_with_rtype(_Bool));
            case '^':
                if (strcmp(sig.methodReturnType, "^v") == 0) {
                    call_block_with_rtype(void);
                    return PMKNull;
                }
                // else fall through!
            default:
                @throw PMKE(@"Unsupported method signature… Why not fork and fix?");
        }
    } @catch (id e) {
      #ifdef PMK_RETHROW_LIKE_A_MOFO
        if ([e isKindOfClass:[NSException class]] && (
            [e name] == NSGenericException ||
            [e name] == NSRangeException ||
            [e name] == NSInvalidArgumentException ||
            [e name] == NSInternalInconsistencyException ||
            [e name] == NSObjectInaccessibleException ||
            [e name] == NSObjectNotAvailableException ||
            [e name] == NSDestinationInvalidException ||
            [e name] == NSPortTimeoutException ||
            [e name] == NSInvalidSendPortException ||
            [e name] == NSInvalidReceivePortException ||
            [e name] == NSPortSendException ||
            [e name] == NSPortReceiveException))
                @throw e;
      #endif
        return NSErrorFromException(e);
    }
}



@implementation CPPromise {
/**
 We have public @implementation instance variables so PMKResolve()
 can fulfill promises. Our usage is like the C++ `friend` keyword.
 */
@public
	dispatch_queue_t _promiseQueue;
    NSMutableArray *_handlers;
    id _result;
}

- (instancetype)init {
    @throw PMKE(@"init is not a valid initializer for CPPromise");
    return nil;
}

#if OS_OBJECT_USE_OBJC == 0
- (void)dealloc {
    dispatch_release(_promiseQueue);
}
#endif

- (CPPromise *(^)(id))then {
    return ^(id block){
        return self.thenOn(dispatch_get_main_queue(), block);
    };
}

- (CPPromise *(^)(id))thenInBackground {
    return ^(id block){
        return self.thenOn(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
    };
}

- (CPPromise *(^)(id))error {
    return ^(id block){
        return self.errorOn(dispatch_get_main_queue(), block);
    };
}

- (CPPromise *(^)(dispatch_block_t))finally {
    return ^(dispatch_block_t block) {
        return self.finallyOn(dispatch_get_main_queue(), block);
    };
}

typedef CPPromise *(^PMKResolveOnQueueBlock)(dispatch_queue_t, id block);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wimplicit-retain-self"

// Convoluted helper method that returns a block that is called
// from a thenOn/catchOn/finallyOn. It returns a block that when
// executed calls the user’s block with our result. The method
// takes two blocks that allow the callee to alter the behavior
// when calling the user’s block. The first for the already-
// resolved state, the second for the pending state.

- (id)resolved:(PMKResolveOnQueueBlock(^)(id result))mkresolvedCallback
       pending:(void(^)(id result, CPPromise *next, dispatch_queue_t q, id block, void (^resolver)(id)))mkpendingCallback
{
    __block PMKResolveOnQueueBlock callBlock;
    __block id result;
    
    dispatch_sync(_promiseQueue, ^{
        if ((result = _result))
            return;

        callBlock = ^(dispatch_queue_t q, id block) {

            // HACK we seem to expose some bug in ARC where this block can
            // be an NSStackBlock which then gets deallocated by the time
            // we get around to using it. So we force it to be malloc'd.
            block = [block copy];

            __block CPPromise *next = nil;

            dispatch_barrier_sync(_promiseQueue, ^{
                if ((result = _result))
                    return;

                __block CPPromiseFulfiller resolver;
                next = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
                    resolver = ^(id o){
                        if (IsError(o)) reject(o); else fulfill(o);
                    };
                }];
                [_handlers addObject:^(id value){
                    mkpendingCallback(value, next, q, block, resolver);
                }];
            });
            
            // next can still be `nil` if the promise was resolved after
            // 1) `-thenOn` read it and decided which block to return; and
            // 2) the call to the block.

            return next ?: mkresolvedCallback(result)(q, block);
        };
    });

    // We could just always return the above block, but then every caller would
    // trigger a barrier_sync on the promise queue. Instead, if we know that the
    // promise is resolved (since that makes it immutable), we can return a simpler
    // block that doesn't use a barrier in those cases.

    return callBlock ?: mkresolvedCallback(result);
}

#pragma clang diagnostic pop

- (PMKResolveOnQueueBlock)thenOn {
    return [self resolved:^(id result) {
        if (IsPromise(result))
            return ((CPPromise *)result).thenOn;

        if (IsError(result)) return ^(dispatch_queue_t q, id block) {
            return [CPPromise promiseWithValue:result];
        };

        return ^(dispatch_queue_t q, id block) {

            // HACK we seem to expose some bug in ARC where this block can
            // be an NSStackBlock which then gets deallocated by the time
            // we get around to using it. So we force it to be malloc'd.
            block = [block copy];

            return dispatch_promise_on(q, ^{
                return pmk_safely_call_block(block, result);
            });
        };
    }
    pending:^(id result, CPPromise *next, dispatch_queue_t q, id block, void (^resolve)(id)) {
        if (IsError(result))
            PMKResolve(next, result);
        else dispatch_async(q, ^{
            resolve(pmk_safely_call_block(block, result));
        });
    }];
}

- (PMKResolveOnQueueBlock)errorOn {
    return [self resolved:^(id result) {
        if (IsPromise(result))
            return ((CPPromise *)result).errorOn;
        
        if (IsError(result)) return ^(dispatch_queue_t q, id block) {

            // HACK we seem to expose some bug in ARC where this block can
            // be an NSStackBlock which then gets deallocated by the time
            // we get around to using it. So we force it to be malloc'd.
            block = [block copy];

            return dispatch_promise_on(q, ^{
                [PMKError consume:result];
                return pmk_safely_call_block(block, result);
            });
        };
        
        return ^(dispatch_queue_t q, id block) {
            return [CPPromise promiseWithValue:result];
        };
    }
    pending:^(id result, CPPromise *next, dispatch_queue_t q, id block, void (^resolve)(id)) {
        if (IsError(result)) {
            dispatch_async(q, ^{
                [PMKError consume:result];
                resolve(pmk_safely_call_block(block, result));
            });
        } else
            PMKResolve(next, result);
    }];
}

- (CPPromise *(^)(dispatch_queue_t, dispatch_block_t))finallyOn {
    return [self resolved:^(id passthru) {
        if (IsPromise(passthru))
            return ((CPPromise *)passthru).finallyOn;

        return ^(dispatch_queue_t q, dispatch_block_t block) {

            // HACK we seem to expose some bug in ARC where this block can
            // be an NSStackBlock which then gets deallocated by the time
            // we get around to using it. So we force it to be malloc'd.
            block = [block copy];

            return dispatch_promise_on(q, ^{
                block();
                return passthru;
            });
        };
    } pending:^(id passthru, CPPromise *next, dispatch_queue_t q, dispatch_block_t block, void (^resolve)(id)) {
        dispatch_async(q, ^{
            @try {
                block();
                resolve(passthru);
            } @catch (id e) {
                resolve(NSErrorFromException(e));
            }
        });
    }];
}

+ (instancetype)promiseWithValue:(id)value {
    CPPromise *p = [self alloc];
    p->_promiseQueue = PMKCreatePromiseQueue();
    p->_result = PMKSanitizeResult(value);
    return p;
}

static dispatch_queue_t PMKCreatePromiseQueue() {
    return dispatch_queue_create("org.promiseKit.Q", DISPATCH_QUEUE_CONCURRENT);
}

static id PMKGetResult(CPPromise *this) {
    __block id result;
    dispatch_sync(this->_promiseQueue, ^{
        result = this->_result;
    });
    return result;
}

static id PMKSanitizeResult(id value) {
    if (!value)
        return PMKNull;
    if (IsError(value))
        [PMKError unconsume:value];
    return value;
}

static NSArray *PMKSetResult(CPPromise *this, id result) {
    __block NSArray *handlers;

    result = PMKSanitizeResult(result);

    dispatch_barrier_sync(this->_promiseQueue, ^{
        handlers = this->_handlers;
        this->_result = result;
        this->_handlers = nil;
    });

    return handlers;
}

static void PMKResolve(CPPromise *this, id result) {
    void (^set)(id) = ^(id r){
        NSArray *handlers = PMKSetResult(this, r);
        for (void (^handler)(id) in handlers)
            handler(r);
    };

    if (IsPromise(result)) {
        CPPromise *next = result;
        dispatch_barrier_sync(next->_promiseQueue, ^{
            id nextResult = next->_result;
            
            if (nextResult == nil) {  // ie. pending
                [next->_handlers addObject:^(id o){
                    PMKResolve(this, o);
                }];
            } else
                set(nextResult);
        });
    } else
        set(result);
}

+ (instancetype)promiseWithResolver:(void (^)(CPPromiseResolver))block {
    CPPromise *this = [self alloc];
    this->_promiseQueue = PMKCreatePromiseQueue();
    this->_handlers = [NSMutableArray new];

    @try {
        block(^(id result){
            if (PMKGetResult(this))
                return PMKLog(@"PromiseKit: Warning: Promise already resolved");

            PMKResolve(this, result);
        });
    } @catch (id e) {
        // at this point, no pointer to the Promise has been provided
        // to the user, so we can’t have any handlers, so all we need
        // to do is set _result. Technically using PMKSetResult is
        // not needed either, but this seems better safe than sorry.
        PMKSetResult(this, NSErrorFromException(e));
    }

    return this;
}

+ (instancetype)promise
{
    return [self promiseWithValue:nil];
}

+ (instancetype)promiseWithBlock:(void(^)(CPPromiseFulfiller fulfill, CPPromiseRejecter reject))block
{
    return [self promiseWithResolver:^(CPPromiseResolver resolve) {
        id rejecter = ^(id error){
            if (error == nil) {
                error = NSErrorFromNil();
            } else if (IsPromise(error) && [error rejected]) {
                // this is safe, acceptable and (basically) valid
            } else if (!IsError(error)) {
                id userInfo = @{NSLocalizedDescriptionKey: [error description], PMKUnderlyingExceptionKey: error};
                error = [NSError errorWithDomain:PMKErrorDomain code:PMKInvalidUsageError userInfo:userInfo];
            }
            resolve(error);
        };
        
        id fulfiller = ^(id result){
            if (IsError(result))
                PMKLog(@"PromiseKit: Warning: PMKFulfiller called with NSError.");
            resolve(result);
        };
        
        block(fulfiller, rejecter);
    }];
}

+ (instancetype)promiseWithAdapter:(void (^)(CPPromiseAdapter))block {
    return [self promiseWithResolver:^(CPPromiseResolver resolve) {
        block(^(id value, id error){
            resolve(error ?: value);
        });
    }];
}

+ (instancetype)promiseWithIntegerAdapter:(void (^)(CPPromiseIntegerAdapter))block {
    return [self promiseWithResolver:^(CPPromiseResolver resolve) {
        block(^(NSInteger value, id error){
            if (error) {
                resolve(error);
            } else {
                resolve(@(value));
            }
        });
    }];
}

+ (instancetype)promiseWithBooleanAdapter:(void (^)(CPPromiseBooleanAdapter adapter))block {
    return [self promiseWithResolver:^(CPPromiseResolver resolve) {
        block(^(BOOL value, id error){
            if (error) {
                resolve(error);
            } else {
                resolve(@(value));
            }
        });
    }];
}

- (BOOL)pending {
	id result = PMKGetResult(self);
    if (IsPromise(result)) {
        return [result pending];
    } else
        return result == nil;
}

- (BOOL)resolved {
    return PMKGetResult(self) != nil;
}

- (BOOL)fulfilled {
	id result = PMKGetResult(self);
    return result != nil && !IsError(result);
}

- (BOOL)rejected {
	id result = PMKGetResult(self);
    return result != nil && IsError(result);
}

- (id)value {
	id result = PMKGetResult(self);
    if (IsPromise(result))
        return [(CPPromise *)result value];
    if ([result isKindOfClass:[PMKArray class]])
        return result[0];
    if (result == PMKNull)
        return nil;
    else
        return result;
}

- (NSString *)description {
    __block id result;
    __block NSUInteger handlerCount;
    dispatch_sync(_promiseQueue, ^{
        result = self->_result;
        handlerCount = self->_handlers.count;
    });
    
    BOOL pending = IsPromise(result) ? [result pending] : (result == nil);
    BOOL resolved = result != nil;
    BOOL fulfilled = resolved && !IsError(result);
    BOOL rejected = resolved && IsError(result);
    
    if (pending)
        return [NSString stringWithFormat:@"Promise: %lu pending handlers", (unsigned long)handlerCount];
    if (rejected)
        return [NSString stringWithFormat:@"Promise: rejected: %@", result];
    
    assert(fulfilled);
    
    return [NSString stringWithFormat:@"Promise: fulfilled: %@", result];
}

+ (CPPromise *)when:(id)promises {
    if ([promises conformsToProtocol:@protocol(NSFastEnumeration)]) {
        return [self all:promises];
    } else if (promises) {
        return [self all:@[promises]].then(^(NSArray *values){
            return values[0];
        });
    } else {
        return [CPPromise promiseWithValue:nil];
    }
}

+ (CPPromise *)all:(id<NSFastEnumeration, NSObject>)promises {
    __block NSUInteger count = [(id)promises count];  // FIXME
    
    if (count == 0)
        return [CPPromise promiseWithValue:promises];
    
    // Keep a reference to the newly created
    // promise so we can check if it's resolved
    // when one of the passed in promises fails.
    __block CPPromise *newPromise = nil;
    
#define rejecter(key) ^(NSError *err){ \
if (newPromise.resolved) \
return; \
id userInfo = err.userInfo.mutableCopy; \
userInfo[PMKFailingPromiseIndexKey] = key; \
err = [NSError errorWithDomain:err.domain code:err.code userInfo:userInfo]; \
rejecter(err); \
}
    
    if ([promises isKindOfClass:[NSDictionary class]])
        return newPromise = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfiller, CPPromiseRejecter rejecter){
            NSMutableDictionary *results = [NSMutableDictionary new];
            for (id key in promises) {
                CPPromise *promise = promises[key];
                if (![promise isKindOfClass:[CPPromise class]])
                    promise = [CPPromise promiseWithValue:promise];
                promise.error(rejecter(key));
                promise.then(^(id o){
                    if (o)
                        results[key] = o;
                    if (--count == 0)
                        fulfiller(results);
                });
            }
        }];
    
    return newPromise = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfiller, CPPromiseRejecter rejecter){
        NSPointerArray *results = nil;
#if TARGET_OS_IPHONE
        results = [NSPointerArray strongObjectsPointerArray];
#else
        if ([[NSPointerArray class] respondsToSelector:@selector(strongObjectsPointerArray)]) {
            results = [NSPointerArray strongObjectsPointerArray];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            results = [NSPointerArray pointerArrayWithStrongObjects];
#pragma clang diagnostic pop
        }
#endif
        results.count = count;
        
        NSUInteger ii = 0;
        
        for (__strong CPPromise *promise in promises) {
            if (![promise isKindOfClass:[CPPromise class]])
                promise = [CPPromise promiseWithValue:promise];
            promise.error(rejecter(@(ii)));
            promise.then(^(id o){
                [results replacePointerAtIndex:ii withPointer:(__bridge void *)(o ?: [NSNull null])];
                if (--count == 0)
                    fulfiller(results.allObjects);
            });
            ii++;
        }
    }];
    
#undef rejecter
}

+ (CPPromise *)until:(id (^)(void))blockReturningPromises catch:(id)failHandler
{
    return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject){
        __block void (^block)() = ^{
            CPPromise *next = [self when:blockReturningPromises()];
            next.then(^(id o){
                fulfill(o);
                block = nil;  // break retain cycle
            });
            next.error(^(NSError *error){
                [CPPromise promiseWithValue:error].error(failHandler).then(block).error(^{
                    reject(error);
                    block = nil;  // break retain cycle
                });
            });
        };
        block();
    }];
}

+ (CPPromise *)join:(NSArray*)promises {
    __block NSMutableArray *mutablePromises = [promises mutableCopy];
    __block NSMutableArray *collectedErrors = [NSMutableArray new];
    
    return [CPPromise until:^id { return mutablePromises; }
                      catch:^(NSError *error) {
                          [collectedErrors addObject:error];
                          [mutablePromises removeObjectAtIndex:[error.userInfo[PMKFailingPromiseIndexKey] unsignedIntegerValue]];
                      }].then(^id(id fulfilledResults) {
                          return PMKManifold(fulfilledResults, (collectedErrors.count ? collectedErrors : nil));
                      });
}

@end



CPPromise *dispatch_promise(id block) {
    return dispatch_promise_on(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

CPPromise *dispatch_promise_on(dispatch_queue_t queue, id block) {
    return [CPPromise promiseWithBlock:^(void(^fulfiller)(id), void(^rejecter)(id)){
        dispatch_async(queue, ^{
            id result = pmk_safely_call_block(block, nil);
            if (IsError(result))
                rejecter(result);
            else
                fulfiller(result);
        });
    }];
}


@implementation PMKArray {
@public id objs[3];
@public NSUInteger count;
}

- (id)objectAtIndexedSubscript:(NSUInteger)idx {
	if (count <= idx) {
        // this check is necessary due to lack of checks in `pmk_safely_call_block`
		return nil;
    }
    return objs[idx];
}

@end

id __PMKArrayWithCount(NSUInteger count, ...) {
    PMKArray *this = [PMKArray new];
    this->count = count;
    va_list args;
    va_start(args, count);
    for (NSUInteger x = 0; x < count; ++x)
        this->objs[x] = va_arg(args, id);
    va_end(args);
    return this;
}



NSOperationQueue *PMKOperationQueue() {
    static NSOperationQueue *q;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = [NSOperationQueue new];
        q.name = @"org.promisekit.Q";
    });
    return q;
}



void *PMKManualReferenceAssociatedObject = &PMKManualReferenceAssociatedObject;
