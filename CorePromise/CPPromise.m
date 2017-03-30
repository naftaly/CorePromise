/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2017 Alexander Cohen
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
 *
 * Totally inspired by https://github.com/mxcl/PromiseKit
 *
 */

#import "CPPromise.h"

NSString* const CorePromiseErrorDomain = @"com.bedroomcode.corepromise.error.domain";
NSString* const CorePromiseFailingIndexKey = @"CorePromiseFailingIndexKey";
NSString* const CorePromiseJoinPromisesKey = @"CorePromiseJoinPromisesKey";

NSString* const CPPromiseNull = @"CPPromiseNull";

static void CPRunCodeOnQueue( NSOperationQueue* queue, dispatch_block_t block )
{
    NSOperationQueue* q = queue ? queue : [NSOperationQueue mainQueue];
    if ( q == [NSOperationQueue currentQueue] )
        block();
    else
        [q addOperationWithBlock:block];
}

@interface CPPromise ()

@property (nonatomic,strong) NSRecursiveLock* lock;
@property (nonatomic,strong) NSMutableArray* handlers;
@property (nonatomic,strong) id result;

@end

@implementation CPPromise

#pragma value

- (id)value
{
    id val = nil;
    
    [self.lock lock];
    
    if ( self.result == CPPromiseNull )
        val = nil;
    else
        val = self.result;
    
    [self.lock unlock];
    
    return val;
}

#pragma state

- (BOOL)isPending
{
    BOOL res = NO;
    [self.lock lock];
    res = self.result == nil;
    [self.lock unlock];
    return res;
}

- (BOOL)isResolved
{
    BOOL res = NO;
    [self.lock lock];
    res = self.result != nil;
    [self.lock unlock];
    return res;
}

- (BOOL)isRejected
{
    BOOL res = NO;
    [self.lock lock];
    res = self.isResolved && [self.result isKindOfClass:[NSError class]];
    [self.lock unlock];
    return res;
}

- (BOOL)isFulfilled
{
    BOOL res = NO;
    [self.lock lock];
    res = self.isResolved && !self.isRejected;
    [self.lock unlock];
    return res;
}

#pragma chaining

- (CPPromiseThenOn)thenOn
{
    return ^id( NSOperationQueue* queue, CPPromiseThenBlock block ) {
        
        return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
            
            
            void (^handleResolvedWithValue)(id o) = ^(id o) {
                
                CPRunCodeOnQueue( queue, ^{
                    
                    if ( [o isKindOfClass:[NSError class]] )
                    {
                        reject(o);
                    }
                    else
                    {
                        id val = block(o);
                        if ( [val isKindOfClass:[NSError class]] )
                            reject(val);
                        else
                            fulfill(val);
                    }
                    
                });
                
            };
            
            if ( self.isResolved )
                handleResolvedWithValue(self.value);
            else
            {
                [self.lock lock];
                [self.handlers addObject:handleResolvedWithValue];
                [self.lock unlock];
            }
            
        }];
        
    };
}

- (CPPromiseThen)then
{
    return ^id( CPPromiseThenBlock block ) {
        return self.thenOn( [NSOperationQueue mainQueue], block );
    };
}

- (CPPromiseErrorOn)errorOn
{
    return ^id( NSOperationQueue* queue, CPPromiseErrorBlock block ) {
        return [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
            
            void (^handleResolvedWithValue)(id o) = ^(id o) {
                
                CPRunCodeOnQueue( queue, ^{
                    
                    if ( [o isKindOfClass:[NSError class]] )
                    {
                        id val = block(o);
                        if ( [val isKindOfClass:[NSError class]] )
                            reject(val);
                        else
                            fulfill(val);
                    }
                    else
                    {
                        fulfill(o);
                    }
                    
                });
                
                
            };
            
            if ( self.isResolved )
                handleResolvedWithValue(self.value);
            else
            {
                [self.lock lock];
                [self.handlers addObject:handleResolvedWithValue];
                [self.lock unlock];
            }
        }];
    };
}

- (CPPromiseError)error
{
    return ^id( CPPromiseErrorBlock block ) {
        return self.errorOn( [NSOperationQueue mainQueue], block );
    };
}

- (CPPromiseFinallyOn)finallyOn
{
    return ^( NSOperationQueue* queue, CPPromiseFinallyBlock block ) {
        [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
            
            void (^handleResolvedWithValue)(id o) = ^(id o) {
                CPRunCodeOnQueue( queue, ^{
                    block(o);
                });
            };

            if ( self.isResolved )
                handleResolvedWithValue(self.value);
            else
            {
                [self.lock lock];
                [self.handlers addObject:handleResolvedWithValue];
                [self.lock unlock];
            }
            
        }];
    };
}

- (CPPromiseFinally)finally
{
    return ^( CPPromiseFinallyBlock block ) {
        return self.finallyOn( [NSOperationQueue mainQueue], block );
    };
}

#pragma resolving

- (void)_resolve:(id)result
{
    if ( _result )
    {
        NSLog( @"[CorePromise-WARNING] Promise has already been resolved, this is probably a programmer error calling resolve twice.", nil );
        return;
    }
    
    void (^set)(id) = ^(id r){
        
        [self.lock lock];
        self.result = r;
        NSArray* handlers = self.handlers;
        self.handlers = nil;
        [self.lock unlock];
        for (void (^handler)(id) in handlers)
            handler(self.value);
    };
    
    result = result ? result : CPPromiseNull;
    if ( [result isKindOfClass:[CPPromise class]] )
    {
        CPPromise* next = result;
        id nextResult = next.result;
        if ( nextResult == nil )
        {
            [next.lock lock];
            [next.handlers addObject:^(id o) {
                [self _resolve:o];
            }];
            [next.lock unlock];
        }
        else
            set(nextResult);
    }
    else
    {
        set(result);
    }
}

#pragma creation

- (instancetype)init
{
    self = [super init];
    _lock = [[NSRecursiveLock alloc] init];
    _handlers = [NSMutableArray array];
    _result = nil;
    return self;
}

+ (instancetype)promiseWithResolverBlock:(CPPromiseResolverBlock)block
{
    CPPromise* promise = [CPPromise new];
    block( ^(id value) {
        [promise _resolve:value];
    });
    return promise;
}

+ (instancetype)promiseWithBlock:(CPPromiseBlock)block
{
    CPPromise* promise = [CPPromise new];
    block( ^(id value) {
        [promise _resolve:value];
    }, ^(NSError* error) {
        [promise _resolve: error ? error : [NSError errorWithDomain:@"" code:0 userInfo:nil]];
    });
    return promise;
}

+ (instancetype)promiseWithValue:(id)value
{
    CPPromise* promise = [[self alloc] init];
    [promise _resolve:value];
    return promise;
}

+ (instancetype)promise
{
    return [CPPromise promiseWithValue:nil];
}

+ (instancetype)promiseWithError:(NSError *)error
{
    return [CPPromise promiseWithValue:error ? error : [NSError errorWithDomain:@"no error" code:0 userInfo:nil]];
}

#pragma multi CPPromise creation

/*
 * rejects as soon as one of the provided promises rejects
 */
+ (instancetype)when:(NSArray<__kindof CPPromise *> *)promises
{
    if ( promises.count == 0 )
        return [CPPromise promiseWithValue:@[]];
    
    NSAssert( [promises isKindOfClass:[NSArray class]], @"Must be an array" );
    [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSAssert( [obj isKindOfClass:[CPPromise class]], @"Each item in the array must be a promise" );
    }];
    
    
    CPPromise* mainPromise = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        __block BOOL alreadyRejected = NO;
        __block NSInteger count = promises.count;
        NSMapTable<CPPromise*,id>* resultsMap = [NSMapTable weakToStrongObjectsMapTable];
        
        void (^resolveOrRejectDone)(NSError* rejectNowError, NSUInteger index) = ^(NSError* rejectNowError, NSUInteger index){
            
            if ( alreadyRejected )
                return;
            
            if ( count == 0 || rejectNowError )
            {
                NSError*        error = nil;
                NSMutableArray* orderedResults = [NSMutableArray array];
                
                if ( rejectNowError )
                {
                    NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithDictionary: rejectNowError.userInfo ?: @{}];
                    userInfo[CorePromiseFailingIndexKey] = @(index);
                    [userInfo setObject:rejectNowError forKey:NSUnderlyingErrorKey];
                    error = [NSError errorWithDomain:rejectNowError.domain code:rejectNowError.code userInfo:userInfo];
                }
                else
                {
                    for ( CPPromise* p in promises )
                    {
                        id res = [resultsMap objectForKey:p];
                        if ( res )
                            [orderedResults addObject:res];
                        else
                            NSLog( @"this should not happen" );
                    }
                }
                
                if ( error )
                {
                    alreadyRejected = YES;
                    reject(error);
                }
                else
                    fulfill( [orderedResults copy] );
            }
        };
        
        [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [resultsMap setObject:[NSNull null] forKey:obj];
            
            obj.then( ^id(id res) {
                [resultsMap setObject: res ? res : [NSNull null] forKey:obj];
                count--;
                resolveOrRejectDone(nil,idx);
                return nil;
            });
            
            obj.error( ^id(NSError* error) {
                [resultsMap setObject: error ? error : [NSError errorWithDomain:@"all error empty" code:0 userInfo:nil] forKey:obj];
                count--;
                resolveOrRejectDone(error,idx);
                return nil;
            });
            
        }];
        
        
        
    }];
    
    return mainPromise;
}

/*
 waits on all provided promises, then rejects if any of those promises rejects, otherwise it fulfills with values from the provided promises.
 */

+ (instancetype)join:(NSArray<__kindof CPPromise *> *)promises
{
    if ( promises.count == 0 )
        return [CPPromise promiseWithValue:@[]];
    
    NSAssert( [promises isKindOfClass:[NSArray class]], @"Must be an array" );
    [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSAssert( [obj isKindOfClass:[CPPromise class]], @"Each item in the array must be a promise" );
    }];
    
    CPPromise* mainPromise = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        __block NSInteger count = promises.count;
        NSMapTable<CPPromise*,id>* resultsMap = [NSMapTable weakToStrongObjectsMapTable];
        
        void (^resolveOrRejectDone)() = ^(){
            if ( count == 0 )
            {
                NSError*        error = nil;
                NSMutableArray* orderedResults = [NSMutableArray array];
                for ( CPPromise* p in promises )
                {
                    id res = [resultsMap objectForKey:p];
                    if ( res )
                    {
                        if ( [res isKindOfClass:[NSError class]] )
                        {
                            error = [NSError errorWithDomain:CorePromiseErrorDomain code:10l userInfo:@{ CorePromiseJoinPromisesKey : promises ? promises : @[] }];
                            break;
                        }
                        [orderedResults addObject:res];
                    }
                    else
                        NSLog( @"this should not happen" );
                }
                
                if ( error )
                    reject(error);
                else
                    fulfill( [orderedResults copy] );
            }
        };
        
        [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [resultsMap setObject:[NSNull null] forKey:obj];
            
            obj.then( ^id(id res) {
                [resultsMap setObject: res ? res : [NSNull null] forKey:obj];
                count--;
                resolveOrRejectDone();
                return nil;
            });
            
            obj.error( ^id(NSError* error) {
                [resultsMap setObject: error ? error : [NSError errorWithDomain:@"all error empty" code:0 userInfo:nil] forKey:obj];
                count--;
                resolveOrRejectDone();
                return nil;
            });
            
        }];
        
        
        
    }];
    
    return mainPromise;
}

+ (instancetype)all:(NSArray<__kindof CPPromise*>*)promises
{
    if ( promises.count == 0 )
        return [CPPromise promiseWithValue:@[]];
    
    NSAssert( [promises isKindOfClass:[NSArray class]], @"Must be an array" );
    [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSAssert( [obj isKindOfClass:[CPPromise class]], @"Each item in the array must be a promise" );
    }];
    
    CPPromise* mainPromise = [CPPromise promiseWithBlock:^(CPPromiseFulfiller fulfill, CPPromiseRejecter reject) {
        
        __block NSInteger count = promises.count;
        NSMapTable<CPPromise*,id>* resultsMap = [NSMapTable weakToStrongObjectsMapTable];
        
        void (^resolveIfDone)() = ^(){
            if ( count == 0 )
            {
                NSMutableArray* orderedResults = [NSMutableArray array];
                for ( CPPromise* p in promises )
                {
                    id res = [resultsMap objectForKey:p];
                    if ( res )
                        [orderedResults addObject:res];
                    else
                        NSLog( @"this should not happen" );
                }
                
                fulfill( [orderedResults copy] );
            }
        };
        
        [promises enumerateObjectsUsingBlock:^(__kindof CPPromise * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            [resultsMap setObject:[NSNull null] forKey:obj];
            
            obj.then( ^id(id res) {
                [resultsMap setObject: res ? res : [NSNull null] forKey:obj];
                count--;
                resolveIfDone();
                return nil;
            });
            
            obj.error( ^id(NSError* error) {
                [resultsMap setObject: error ? error : [NSError errorWithDomain:@"all error empty" code:0 userInfo:nil] forKey:obj];
                count--;
                resolveIfDone();
                return nil;
            });
            
        }];
        
        
        
    }];
    
    return mainPromise;
}

@end

#ifndef __cplusplus
@implementation CPPromise (Cacthing)
- (CPPromiseError)catch { return self.error; }
@end
#endif

CPPromise* CorePromiseAfter(NSTimeInterval time)
{
    return [CPPromise promiseWithResolverBlock:^(CPPromiseResolver  _Nonnull resolver) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            resolver(@(time));
        });
    }];
}

CPPromise* CorePromiseJoin(NSArray* promises)
{
    return [CPPromise join:promises];
}

CPPromise* CorePromiseWhen(NSArray* promises)
{
    return [CPPromise when:promises];
}

CPPromise* CorePromiseAll(NSArray* promises)
{
    return [CPPromise all:promises];
}

CPPromise* CorePromiseDispatchOn( NSOperationQueue* queue, CPPromiseThenBlock block)
{
    return [CPPromise promiseWithValue:nil].thenOn(queue, block);
}

CPPromise* CorePromiseDispatch(CPPromiseThenBlock block)
{
    static NSOperationQueue* queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[NSOperationQueue alloc] init];
    });
    return CorePromiseDispatchOn(queue, block);
}

id CorePromiseHang( CPPromise* promise)
{
    if ( promise.isPending )
    {
        static CFRunLoopSourceContext context;
        
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        CFRunLoopSourceRef runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
        CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
        
        promise.finally(^(id nop){
            CFRunLoopStop(runLoop);
        });
        while (promise.isPending) {
            CFRunLoopRun();
        }
        CFRunLoopRemoveSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
    }
    
    return promise.value;
}
