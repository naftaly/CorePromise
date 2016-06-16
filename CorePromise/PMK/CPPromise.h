#import <Foundation/Foundation.h>

/**
 A promise represents the future value of a task.

 To obtain the value of a promise we call `then`.

 Promises are chainable: `then` returns a promise, you can call `then` on that promise, which  returns a promise, you can call `then` on that promise, et cetera.

 Promises start in a pending state: they have `nil` value. Promises *resolve* to become *fulfilled* or *rejected*. A rejected promise has an `NSError` for its value, a fulfilled promise has any other object as its value.

 @see [PromiseKit `then` Guide](http://promisekit.org/then/)
 @see [PromiseKit Chaining Guide](http://promisekit.org/chaining/)
*/

FOUNDATION_EXTERN NSString* const CorePromiseErrorDomain;

typedef void (^CPPromiseFulfiller)(id);
typedef void (^CPPromiseRejecter)(NSError *);
typedef void (^CPPromiseResolver)(id);
typedef void (^CPPromiseAdapter)(id, NSError *);
typedef void (^CPPromiseIntegerAdapter)(NSInteger, NSError *);
typedef void (^CPPromiseBooleanAdapter)(BOOL, NSError *);

@interface CPPromise : NSObject


- (CPPromise *(^)(id))then;
- (CPPromise *(^)(id))error;
- (CPPromise *(^)(void(^)(void)))finally;

- (CPPromise *(^)(id))thenInBackground;
- (CPPromise *(^)(dispatch_queue_t, id))thenOn;
- (CPPromise *(^)(dispatch_queue_t, id))errorOn;
- (CPPromise *(^)(dispatch_queue_t, void(^)(void)))finallyOn;

+ (CPPromise *)when:(id)promiseOrArrayOfPromisesOrValue;
+ (CPPromise *)all:(id<NSFastEnumeration, NSObject>)enumerable;
+ (CPPromise *)until:(id(^)(void))blockReturningPromiseOrArrayOfPromises catch:(id)catchHandler;
+ (CPPromise *)join:(NSArray *)promises;

@property (nonatomic,readonly) BOOL pending;
@property (nonatomic,readonly) BOOL resolved;
@property (nonatomic,readonly) BOOL fulfilled;
@property (nonatomic,readonly) BOOL rejected;

@property (nonatomic,readonly) id value;

+ (instancetype)promise;
+ (instancetype)promiseWithValue:(id)value;
+ (instancetype)promiseWithBlock:(void(^)(CPPromiseFulfiller fulfill, CPPromiseRejecter reject))block;
+ (instancetype)promiseWithResolver:(void (^)(CPPromiseResolver resolve))block;
+ (instancetype)promiseWithAdapter:(void (^)(CPPromiseAdapter adapter))block;
+ (instancetype)promiseWithIntegerAdapter:(void (^)(CPPromiseIntegerAdapter adapter))block;
+ (instancetype)promiseWithBooleanAdapter:(void (^)(CPPromiseBooleanAdapter adapter))block;

@end


#define PMKManifold(...) __PMKManifold(__VA_ARGS__, 3, 2, 1)
#define __PMKManifold(_1, _2, _3, N, ...) __PMKArrayWithCount(N, _1, _2, _3)
extern id __PMKArrayWithCount(NSUInteger, ...);

CPPromise *dispatch_promise(id block);
CPPromise *dispatch_promise_on(dispatch_queue_t q, id block);
extern void (^PMKUnhandledErrorHandler)(NSError *);
