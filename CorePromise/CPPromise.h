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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger,CorePromiseError) {
    CorePromiseErrorNone = 0,
    CorePromiseErrorException
};

extern NSString* const CorePromiseErrorDomain;
extern NSString* const CorePromiseFailingIndexKey;
extern NSString* const CorePromiseJoinPromisesKey;
extern NSString* const CorePromiseExceptionErrorKey;

typedef void(^CPPromiseResolver)(id _Nullable value);
typedef void(^CPPromiseFulfiller)(id _Nullable value);
typedef void(^CPPromiseRejecter)(NSError* _Nullable error);
typedef void(^CPPromiseBlock)( CPPromiseFulfiller fulfill, CPPromiseRejecter reject );
typedef void(^CPPromiseResolverBlock)(CPPromiseResolver resolver);

@interface CPPromise<__covariant ObjectType> : NSObject

/*
 * blocks used within scope
 */
typedef id _Nullable(^CPPromiseThenBlock)(ObjectType __nullable value);
typedef CPPromise* _Nonnull(^CPPromiseThen)( CPPromiseThenBlock block );
typedef CPPromise* _Nonnull(^CPPromiseThenOn)( NSOperationQueue* queue, CPPromiseThenBlock block );

typedef id _Nullable(^CPPromiseErrorBlock)(NSError* error);
typedef CPPromise* _Nonnull(^CPPromiseError)( CPPromiseErrorBlock block );
typedef CPPromise* _Nonnull(^CPPromiseErrorOn)( NSOperationQueue* queue, CPPromiseErrorBlock block );

typedef void(^CPPromiseFinallyBlock)(ObjectType __nullable value);
typedef void(^CPPromiseFinally)( CPPromiseFinallyBlock block );
typedef void(^CPPromiseFinallyOn)( NSOperationQueue* queue, CPPromiseFinallyBlock block );

/*
 * creation
 */
+ (instancetype)promise;
+ (instancetype)promiseWithValue:(nullable ObjectType)value;
+ (instancetype)promiseWithError:(nullable NSError*)error;
+ (instancetype)promiseWithBlock:(CPPromiseBlock)block;
+ (instancetype)promiseWithResolverBlock:(CPPromiseResolverBlock)block;
+ (instancetype)all:(NSArray<__kindof CPPromise*>*)promises;
+ (instancetype)join:(NSArray<__kindof CPPromise*>*)promises;
+ (instancetype)when:(NSArray<__kindof CPPromise*>*)promises;

/*
 * state
 */
@property (nonatomic,readonly,getter=isPending) BOOL pending;
@property (nonatomic,readonly,getter=isRejected) BOOL rejected;
@property (nonatomic,readonly,getter=isFulfilled) BOOL fulfilled;
@property (nonatomic,readonly,getter=isResolved) BOOL resolved;

/*
 * value
 */
@property (nullable, nonatomic,readonly) id value;

/*
 * chaining
 */
@property (nonatomic,copy,readonly) CPPromiseThen then;
@property (nonatomic,copy,readonly) CPPromiseError error;
@property (nonatomic,copy,readonly) CPPromiseFinally finally;

@property (nonatomic,copy,readonly) CPPromiseThenOn thenOn;
@property (nonatomic,copy,readonly) CPPromiseErrorOn errorOn;
@property (nonatomic,copy,readonly) CPPromiseFinallyOn finallyOn;

@end

#ifdef __cplusplus
extern "C" {
#endif
    
/*
 * this is mostly for tests and compatibility with PromiseKit
 */
extern CPPromise* CorePromiseAfter(NSTimeInterval time);
extern CPPromise* CorePromiseJoin(NSArray* promises);
extern CPPromise* CorePromiseWhen(NSArray* promises);
extern CPPromise* CorePromiseAll(NSArray* promises);
extern id         CorePromiseHang(CPPromise* promise);

extern CPPromise* CorePromiseDispatchOn(NSOperationQueue* queue, CPPromiseThenBlock block);
extern CPPromise* CorePromiseDispatch(CPPromiseThenBlock block);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
