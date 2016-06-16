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

@interface CPPromiseHandlers : NSObject

@property (nonatomic,copy) CorePromiseFulfillHandler onFulfullied;
@property (nonatomic,copy) CorePromiseRejectHandler onRejected;

@end

@implementation CPPromiseHandlers
@end

@interface CPPromise ()

@property (nonatomic,assign) CorePromiseState state;
@property (nonatomic,strong) id value;
@property (nonatomic,strong) NSMutableArray<CPPromiseHandlers*>* handlers;

@property (nonatomic,copy) CorePromiseBlock then;
@property (nonatomic,copy) CorePromiseBlock done;

@end

@implementation CPPromise

+ (instancetype)promise
{
    return [self promiseWithValue:nil];
}

+ (instancetype)promiseWithValue:(id)value
{
    return [self promiseWithBlock:^CPPromise *(CorePromiseFulfillHandler onFulfill, CorePromiseRejectHandler onRejected) {
        return onFulfill(value);
    }];
}

+ (instancetype)when:(NSArray<CPPromise *> *)promises
{
    return nil;
}

+ (instancetype)promiseWithBlock:(CorePromiseBlock)fn
{
    return [[[self class] alloc] initWithFn:fn];
}

- (instancetype)initWithFn:(CorePromiseBlock)fn
{
    self = [super init];

    NSLog( @"<%p> [CPPromise initWithFn:]", self );
    
    _value = nil;
    _state = CorePromiseStatePending;
    _handlers = [NSMutableArray array];
    
    __weak typeof(self)weakMe = self;
    
    self.done = ^CPPromise*( CorePromiseFulfillHandler onFulfilled, CorePromiseRejectHandler onRejected ) {
        
        typeof(self)me = weakMe;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            CPPromiseHandlers* h = [CPPromiseHandlers new];
            h.onFulfullied = onFulfilled;
            h.onRejected = onRejected;
            [me handle:h];
        }];
        
        return [me doResolve:fn fulfill:^id(id value) {
            return [me resolve:value];
        } reject:^id(id error) {
            return [me reject:error];
        }];

    };
    
    self.then = ^CPPromise*( CorePromiseFulfillHandler onFulfilled, CorePromiseRejectHandler onRejected ) {
        
        typeof(self)me = weakMe;
        
        return [CPPromise promiseWithBlock:^CPPromise*(CorePromiseFulfillHandler resolve, CorePromiseRejectHandler reject) {
            
            return me.done( ^id(id result) {
                
                if ( onFulfilled )
                {
                    
                    @try {
                        return resolve( onFulfilled(result) );
                    } @catch (NSException *exception) {
                        return reject(exception);
                    }
                }
                else
                {
                    return resolve(result);
                }
                
            }, ^id(id error) {
               
                if ( onRejected )
                {
                    
                    @try {
                        return resolve( onRejected(error) );
                    } @catch (NSException *exception) {
                        return reject(exception);
                    }
                }
                else
                {
                    return reject(error);
                }

                
            });
            
        }];
        
    };
    
    [self doResolve:fn fulfill:^id(id value) {
        return [self resolve:value];
    } reject:^id(id error) {
        return [self reject:error];
    }];
    
    return self;
}

- (id)fulfill:(id)val
{
    NSLog( @"<%p> [CPPromise fulfill:]", self );
    
    self.state = CorePromiseStateFulfilled;
    self.value = val;
    [self.handlers enumerateObjectsUsingBlock:^(CPPromiseHandlers * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self handle:obj];
    }];
    self.handlers = nil;
    return nil;
}

- (id)reject:(id)error
{
    NSLog( @"<%p> [CPPromise reject:]", self );
    
    self.state = CorePromiseStateRejected;
    self.value = error;
    [self.handlers enumerateObjectsUsingBlock:^(CPPromiseHandlers * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self handle:obj];
    }];
    self.handlers = nil;
    return nil;
}

/**
 * Check if a value is a Promise and, if it is,
 * return the `then` method of that promise.
 *
 * @param {Promise|Any} value
 * @return {Function|Null}
 */
- (id)getThen:(id)value
{
    NSLog( @"<%p> [CPPromise getThen:]", self );
    
    if ( [value isKindOfClass:[CPPromise class]] )
    {
        id then = ((CPPromise*)value).then;
        // check if then is a function
        return then;
    }
    return nil;
}

/*
 result is a value or a promise
 */
- (id)resolve:(id)result
{
    NSLog( @"<%p> [CPPromise resolve:]", self );
    
    @try {
        
        id then = [self getThen:result];
        if ( then )
        {
            return [self doResolve:then fulfill:^id(id value) {
                return [self resolve:value];
            } reject:^id(id reason) {
                return [self reject:reason];
            }];
            
            //[self doResolve: then.bind(result) resolve:@selector(resolve:) reject:@selector(reject:)];
        }
        return [self fulfill:result];
        
    } @catch (NSException *exception) {
        
        return [self reject:exception];
        
    }
    
}

- (void)handle:(CPPromiseHandlers*)handler
{
    NSLog( @"<%p> [CPPromise handle:]", self );
    
    if ( self.state == CorePromiseStatePending )
    {
        [self.handlers addObject:handler];
    }
    else
    {
        if ( self.state == CorePromiseStateFulfilled && handler.onFulfullied )
        {
            handler.onFulfullied(self.value);
        }
        if ( self.state == CorePromiseStateRejected && handler.onRejected )
        {
            handler.onRejected(self.value);
        }
        
    }
}

/**
 * Take a potentially misbehaving resolver function and make sure
 * onFulfilled and onRejected are only called once.
 *
 * Makes no guarantees about asynchrony.
 *
 * @param {Function} fn A resolver function that may not be trusted
 * @param {Function} onFulfilled
 * @param {Function} onRejected
 */

- (id)doResolve:(CorePromiseBlock)fn fulfill:(CorePromiseFulfillHandler)onFulfilled reject:(CorePromiseRejectHandler)onRejected
{
    NSLog( @"<%p> [CPPromise doResolve:fulfill:reject:]", self );
    
    __block BOOL done = NO;
    
    @try {
        
        fn( ^id(id value) {
            
            if ( done ) return nil;
            done = YES;
            return onFulfilled(value);
            
        }, ^id(NSError* err) {
            
            if ( done ) return nil;
            done = YES;
            return onRejected(err);
            
        });
        
    } @catch (NSException *exception) {
        
        if ( done ) return nil;
        done = YES;
        return onRejected(exception);
        
    }
}

- (void)setState:(CorePromiseState)state
{
    if ( state != _state )
    {
        [self willChangeValueForKey:@"state"];
        _state = state;
        [self didChangeValueForKey:@"state"];
    }
}


@end




