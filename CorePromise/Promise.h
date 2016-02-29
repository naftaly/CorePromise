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

#import <Foundation/Foundation.h>

/* error domain when errors come from CorePromise */
FOUNDATION_EXTERN NSString* const PromiseErrorDomain;

/* NSError.userInfo key if an exception is raised in a handler */
FOUNDATION_EXTERN NSString* const PromiseErrorExceptionKey;

typedef NS_ENUM(NSUInteger,PromiseErrorCode) {
    PromiseErrorCodeNone,
    PromiseErrorCodeException
} NS_ENUM_AVAILABLE(10_11, 9_0);

NS_CLASS_AVAILABLE(10_11,9_0) @interface Promise<__covariant ValueType> : NSObject

typedef Promise*(^PromiseHandler)( id (^)(ValueType obj) );
typedef Promise*(^PromiseOnHandler)( NSOperationQueue*, id (^)(ValueType obj) );

@property (nonatomic,copy,readonly) PromiseOnHandler thenOn;
@property (nonatomic,copy,readonly) PromiseHandler then;
@property (nonatomic,copy,readonly) PromiseHandler error;
@property (nonatomic,copy,readonly) PromiseHandler finally;

/* a promise is resolved when value != nil */
@property (nonatomic,readonly) id/* ValueType */ value;

/* creates a promise in a pending state. call markStateWithValue: when you are ready */
+ (instancetype)pendingPromise;

/* creates a promise in a rejected state */
+ (instancetype)rejectedPromiseWithError:(NSError*)error;

/* creates a fulfilled promised with a nil value */
+ (instancetype)promise;

/* creates a fulfilled/rejected promised with a value of 'value' */
+ (instancetype)promiseWithValue:(id)value;

/* mark a promise as fulfilled or rejected. if value is an NSError, the promise is rejected. */
- (void)markStateWithValue:(id)value;

/* debugging faciity to name a promise */
@property (nonatomic,copy) NSString* name;

/* the root promise in this chain */
@property (nonatomic,readonly) Promise* root;

/* the parent promise */
@property (nonatomic,weak,readonly) Promise* parent;

@end









