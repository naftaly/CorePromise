/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2016 Alexander Cohen
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import "CPPromise.h"

#define LOG_DEBUG   0

NSString* const CorePromiseErrorDomain = @"com.bedroomcode.core.promise.error.domain";
NSString* const CorePromiseErrorExceptionKey = @"PromiseErrorExceptionKey";

typedef NS_ENUM(NSUInteger,CorePromiseState) {
    CorePromiseStatePending,
    CorePromiseStateFulfilled,
    CorePromiseStateRejected
};

@interface ThenPromise : CPPromise
@end
@implementation ThenPromise
@end

@interface ErrorPromise : CPPromise
@end
@implementation ErrorPromise
@end

@interface FinallyPromise : CPPromise
@end
@implementation FinallyPromise
@end

@interface CPPromise ()

@property (nonatomic,assign) CorePromiseState state;
@property (nonatomic,assign) NSInteger identifier;
@property (nonatomic,strong) id value;

@property (nonatomic,copy) CorePromiseOnHandler thenOn;
@property (nonatomic,copy) CorePromiseHandler then;
@property (nonatomic,copy) CorePromiseHandler error;
@property (nonatomic,copy) CorePromiseHandler finally;

@property (nonatomic,weak) CPPromise* parent;

@property (nonatomic,strong) CPPromise* nextPromise;
@property (nonatomic,readonly) CPPromise* lastPromiseInChain;

- (CPPromise*)_makeThen:(CPPromise* (^)(id obj))block on:(NSOperationQueue*)queue;
- (CPPromise*)_makeError:(CPPromise* (^)(id obj))block;
- (CPPromise*)_makeFinally:(CPPromise* (^)(id obj))block;

@property (nonatomic,strong) NSOperationQueue* _callbackQueue;
@property (nonatomic,copy) CPPromise* (^_callback)(id obj);

@end

@implementation CPPromise

- (instancetype)init
{
    static NSInteger count = 0;
    count++;
    self = [super init];
    _identifier = count;
    _value = nil;
    _state = CorePromiseStatePending;
    
#if LOG_DEBUG
    NSLog( @"[%@ init:] %ld", NSStringFromClass(self.class), self.identifier );
#endif
    
    __weak typeof(self)weakMe = self;
    
    self.thenOn = ^ CPPromise* (NSOperationQueue* queue, id obj) {
        typeof(self)me = weakMe;
        return [me _makeThen:obj on:queue];
    };
    
    self.then = ^ CPPromise* (id obj) {
        typeof(self)me = weakMe;
        return [me _makeThen:obj on:nil];
    };
    
    self.error = ^ CPPromise* (id obj) {
        typeof(self)me = weakMe;
        return [me _makeError:obj];
    };
    
    self.finally = ^ CPPromise* (id obj) {
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

- (CPPromise*)lastPromiseInChain
{
    CPPromise* p = self;
    while (p.nextPromise) {
        p = p.nextPromise;
    }
    return p;
}

- (CPPromise*)_findNextNonErrorAndNonFinallyPromise
{
    CPPromise* p = self.nextPromise;
    while ( p && ( [p isKindOfClass:[ErrorPromise class]] || [p isKindOfClass:[FinallyPromise class]] ) )
        p = p.nextPromise;
    return p;
}

- (CPPromise*)_findNextErrorPromise
{
    CPPromise* p = self.nextPromise;
    while ( p && ![p isKindOfClass:[ErrorPromise class]] )
        p = p.nextPromise;
    return p;
}

- (CPPromise*)_findFinallyPromise
{
    CPPromise* p = self.nextPromise;
    while ( p && ![p isKindOfClass:[FinallyPromise class]] )
        p = p.nextPromise;
    return p;
}

- (id)_callCallbackWithValue:(id)value
{
    id res = nil;
    
    @try
    {
        res = self._callback(value);
    }
    @catch (NSException *exception)
    {
        res = [NSError errorWithDomain:CorePromiseErrorDomain code:CorePromiseErrorCodeException userInfo:@{ NSLocalizedDescriptionKey : [exception description], CorePromiseErrorExceptionKey : exception }];
    }
    @catch (id exceptionValue)
    {
        res = [NSError errorWithDomain:CorePromiseErrorDomain code:CorePromiseErrorCodeException userInfo:@{ NSLocalizedDescriptionKey : [exceptionValue description] }];
    }

    return res;
}

- (void)_bubbleValueToNextPromise
{
    if( self.state == CorePromiseStateFulfilled )
    {
        // find the upcoming "then" promise
        CPPromise* p = [self _findNextNonErrorAndNonFinallyPromise];
        if ( p && p._callback )
        {
            [p._callbackQueue addOperationWithBlock:^{
                
                id res = [p _callCallbackWithValue:self.value];
                
                // insert the new promise between our p and its next promise
                if ( [res isKindOfClass:[CPPromise class]] )
                {
                    CPPromise* nextPromiseResult = res;
                    CPPromise* nextPromiseResultChainEnd = nextPromiseResult.lastPromiseInChain;
                    CPPromise* pNextPromise = p.nextPromise;
                    if ( pNextPromise )
                    {
                        p.nextPromise = nextPromiseResult;
                        nextPromiseResult.parent = p.nextPromise;
                        nextPromiseResultChainEnd.nextPromise = pNextPromise;
                    }
                }
                
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [p markStateWithValue:res];
                }];

            }];
            
        }
        else if ( !p )
        {
            // nothing left, it's time for finally
            p = [self _findFinallyPromise];
            if ( p && p._callback )
            {
                [p._callbackQueue addOperationWithBlock:^{
                    [p _callCallbackWithValue:self.value];
                }];
            }
        }
    }
    else if ( self.state == CorePromiseStateRejected )
    {
        CPPromise* nextErrorPromise = [self _findNextErrorPromise];
        CPPromise* nextThenPromise = [self _findNextNonErrorAndNonFinallyPromise];
        
        if ( nextErrorPromise && nextErrorPromise._callback )
        {
            [nextErrorPromise._callbackQueue addOperationWithBlock:^{
                
                id res = [nextErrorPromise _callCallbackWithValue:self.value];
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [nextErrorPromise markStateWithValue:res];
                }];
                
            }];
            
        }
        else if ( nextThenPromise )
        {
            [nextThenPromise markStateWithValue:self.value];
        }
    }
}

- (void)markStateWithValue:(id)value
{
    NSAssert( self.state == CorePromiseStatePending, @"State is not pending" );
    
    self.value = value;
    self.state = [value isKindOfClass:[NSError class]] ? CorePromiseStateRejected : CorePromiseStateFulfilled;
    [self _bubbleValueToNextPromise];
}

+ (instancetype)promiseWithValue:(id)value
{
    CPPromise* p = [self pendingPromise];
    dispatch_async( dispatch_get_main_queue(), ^{
        if ( !p.parent )
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

- (CPPromise*)_makeFinally:(CPPromise* (^)(id obj))block
{
#if LOG_DEBUG
    NSLog( @"[Promise _finally:] %ld", self.identifier );
#endif
    
    CPPromise* p = [FinallyPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    p._callbackQueue = [NSOperationQueue mainQueue];
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;
    
    self.nextPromise = p;
    
    return p;
}

- (CPPromise*)_makeThen:(CPPromise* (^)(id obj))block on:(NSOperationQueue*)queue
{
#if LOG_DEBUG
    NSLog( @"[Promise _then:] %ld", self.identifier );
#endif
    
    CPPromise* p = [ThenPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    p._callbackQueue = queue ? queue : [NSOperationQueue mainQueue];
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;

    self.nextPromise = p;
    
    return p;
}

- (CPPromise*)_makeError:(CPPromise* (^)(id obj))block
{
#if LOG_DEBUG
    NSLog( @"[Promise _error:] %ld", self.identifier );
#endif
    
    CPPromise* p = [ErrorPromise pendingPromise];
    p.parent = self;
    p._callback = block;
    p._callbackQueue = [NSOperationQueue mainQueue];
    
    if ( self.nextPromise )
        self.nextPromise.parent = nil;
    
    self.nextPromise = p;
    
    return p;
}

- (CPPromise*)root
{
    CPPromise* r = self;
    while (r.parent)
        r = r.parent;
    return r;
}

@end




