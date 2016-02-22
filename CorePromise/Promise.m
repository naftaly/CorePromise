//
//  Promise.m
//  Promises
//
//  Created by Alexander Cohen on 2016-02-21.
//  Copyright © 2016 X-Rite, Inc. All rights reserved.
//

#import "Promise.h"

#define LOG_DEBUG   0

typedef NS_ENUM(NSUInteger,PromiseState) {
    PromiseStatePending,
    PromiseStateFulfilled,
    PromiseStateRejected
};

@interface ThenPromise : Promise
@end
@implementation ThenPromise
@end

@interface ErrorPromise : Promise
@end
@implementation ErrorPromise
@end

@interface FinallyPromise : Promise
@end
@implementation FinallyPromise
@end

@interface Promise ()

@property (nonatomic,assign) PromiseState state;
@property (nonatomic,assign) NSInteger identifier;
@property (nonatomic,strong) id value;

@property (nonatomic,copy) PromiseHandler then;
@property (nonatomic,copy) PromiseHandler error;
@property (nonatomic,copy) PromiseHandler finally;

@property (nonatomic,weak) Promise* parent;

@property (nonatomic,strong) Promise* nextPromise;
@property (nonatomic,readonly) Promise* lastPromiseInChain;

- (Promise*)_makeThen:(Promise* (^)(id obj))block;
- (Promise*)_makeError:(Promise* (^)(id obj))block;
- (Promise*)_makeFinally:(Promise* (^)(id obj))block;

@property (nonatomic,copy) Promise* (^_callback)(id obj);

@end

@implementation Promise

- (instancetype)init
{
    static NSInteger count = 0;
    count++;
    self = [super init];
    _identifier = count;
    _value = nil;
    _state = PromiseStatePending;
    
#if LOG_DEBUG
    NSLog( @"[%@ init:] %ld", NSStringFromClass(self.class), self.identifier );
#endif
    
    __weak typeof(self)weakMe = self;
    
    self.then = ^ Promise* (id obj) {
        typeof(self)me = weakMe;
        return [me _makeThen:obj];
    };
    
    self.error = ^ Promise* (id obj) {
        typeof(self)me = weakMe;
        return [me _makeError:obj];
    };
    
    self.finally = ^ Promise* (id obj) {
        typeof(self)me = weakMe;
        return [me _makeFinally:obj];
    };
    
    return self;
}

- (void)dealloc
{
#if LOG_DEBUG
    NSLog( @"[%@ dealloc:] %ld", NSStringFromClass(self.class), self.identifier );
#endif
    
}

- (Promise*)lastPromiseInChain
{
    Promise* p = self;
    while (p.nextPromise) {
        p = p.nextPromise;
    }
    return p;
}

- (Promise*)_findNextNonErrorAndNonFinallyPromise
{
    Promise* p = self.nextPromise;
    while ( p && ( [p isKindOfClass:[ErrorPromise class]] || [p isKindOfClass:[FinallyPromise class]] ) )
        p = p.nextPromise;
    return p;
}

- (Promise*)_findNextErrorPromise
{
    Promise* p = self.nextPromise;
    while ( p && ![p isKindOfClass:[ErrorPromise class]] )
        p = p.nextPromise;
    return p;
}

- (Promise*)_findFinallyPromise
{
    Promise* p = self.nextPromise;
    while ( p && ![p isKindOfClass:[FinallyPromise class]] )
        p = p.nextPromise;
    return p;
}

- (void)_bubbleValueToNextPromise
{
    if( self.state == PromiseStateFulfilled )
    {
        // find the upcoming "then" promise
        Promise* p = [self _findNextNonErrorAndNonFinallyPromise];
        if ( p && p._callback )
        {
            id res = p._callback(self.value);
            
            // insert the new promise between our p and its next promise
            if ( [res isKindOfClass:[Promise class]] )
            {
                Promise* nextPromiseResult = res;
                Promise* nextPromiseResultChainEnd = nextPromiseResult.lastPromiseInChain;
                Promise* pNextPromise = p.nextPromise;
                if ( pNextPromise )
                {
                    p.nextPromise = nextPromiseResult;
                    nextPromiseResult.parent = p.nextPromise;
                    nextPromiseResultChainEnd.nextPromise = pNextPromise;
                }
            }
            
            [p markStateWithValue:res];
        }
        else if ( !p )
        {
            // nothing left, it's time for finally
            p = [self _findFinallyPromise];
            if ( p && p._callback )
                p._callback(self.value);
        }
    }
    else if ( self.state == PromiseStateRejected )
    {
        Promise* nextErrorPromise = [self _findNextErrorPromise];
        Promise* nextThenPromise = [self _findNextNonErrorAndNonFinallyPromise];
        
        if ( nextErrorPromise && nextErrorPromise._callback )
        {
            id res = nextErrorPromise._callback(self.value);
            [nextErrorPromise markStateWithValue:res];
        }
        else if ( nextThenPromise )
        {
            [nextThenPromise markStateWithValue:self.value];
        }
    }
}

- (void)markStateWithValue:(id)value
{
    NSAssert( self.state == PromiseStatePending, @"State is not pending" );
    
    self.value = value;
    self.state = [value isKindOfClass:[NSError class]] ? PromiseStateRejected : PromiseStateFulfilled;
    [self _bubbleValueToNextPromise];
}

+ (instancetype)promiseWithValue:(id)value
{
    Promise* p = [self pendingPromise];
    dispatch_async( dispatch_get_main_queue(), ^{
        [p markStateWithValue:value];
    });
    return p;
}

+ (instancetype)pendingPromise
{
    return [[self alloc] init];
}

+ (instancetype)promise
{
    return [self promiseWithValue:nil];
}

- (Promise*)_makeFinally:(Promise* (^)(id obj))block
{
#if LOG_DEBUG
    NSLog( @"[Promise _finally:] %ld", self.identifier );
#endif
    
    Promise* p = [FinallyPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;
    
    self.nextPromise = p;
    
    return p;
}

- (Promise*)_makeThen:(Promise* (^)(id obj))block
{
#if LOG_DEBUG
    NSLog( @"[Promise _then:] %ld", self.identifier );
#endif
    
    Promise* p = [ThenPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;

    self.nextPromise = p;
    
    return p;
}

- (Promise*)_makeError:(Promise* (^)(id obj))block
{
#if LOG_DEBUG
    NSLog( @"[Promise _error:] %ld", self.identifier );
#endif
    
    Promise* p = [ErrorPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;
    
    self.nextPromise = p;
    
    return p;
}

- (Promise*)root
{
    Promise* r = self;
    while (r.parent)
        r = r.parent;
    return r;
}

@end




