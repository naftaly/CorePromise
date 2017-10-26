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

#import <CorePromise/CorePromise.h>
@import XCTest;

static inline NSError *dummyWithCode(NSInteger code) {
    return [NSError errorWithDomain:CorePromiseErrorDomain code:rand() userInfo:@{NSLocalizedDescriptionKey: @(code).stringValue}];
}

static inline NSError *dummy() {
    return dummyWithCode(rand());
}

static inline CPPromise *rejectLater() {
    return [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                resolve(dummy());
            });
        });
    }];
}

static inline CPPromise *fulfillLater() {
    return [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            resolve(@1);
        });
    }];
}


@interface CPPromiseTestSuite : XCTestCase @end @implementation CPPromiseTestSuite

- (void)test_01_resolve {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }];
    promise.then(^id(NSNumber *o){
        [ex1 fulfill];
        XCTAssertEqual(o.intValue, 1);
        return nil;
    });
    promise.error(^id(NSError* err){
        XCTFail();
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_02_reject {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(dummyWithCode(2));
    }];
    promise.then(^id(id nop){
        XCTFail();
        return nil;
    });
    promise.error(^id(NSError *error){
        XCTAssertEqualObjects(error.localizedDescription, @"2");
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_03_return_error {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@2);
    }];
    promise.then(^id(id nop){
        return [NSError errorWithDomain:@"a" code:3 userInfo:nil];
    }).error(^id(NSError *e){
        [ex1 fulfill];
        XCTAssertEqual(3, e.code);
        return nil;
    });
    promise.error(^id(NSError* error){
        XCTFail();
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_04_return_error_doesnt_compromise_result {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@4);
    }].then(^id(id nop){
        return dummy();
    });
    promise.then(^id(id nop){
        XCTFail();
        return nil;
    });
    promise.error(^id(id nop){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_05_throw_and_bubble {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@5);
    }].then(^(id ii){
        XCTAssertEqual(5, [ii intValue]);
        return [NSError errorWithDomain:@"a" code:[ii intValue] userInfo:nil];
    }).error(^id(NSError *e){
        XCTAssertEqual(e.code, 5);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_05_throw_and_bubble_more {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@5);
    }].then(^id(id nop){
        return dummy();
    }).then(^id(id nop){
        //NOOP
        return nil;
    }).error(^id(NSError *e){
        [ex1 fulfill];
        XCTAssertEqualObjects(e.domain, CorePromiseErrorDomain);
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_06_return_error {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@5);
    }].then(^id(id nop){
        return dummy();
    }).error(^id(id nop){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_07_can_then_resolved {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }].then(^id(id o){
        [ex1 fulfill];
        XCTAssertEqualObjects(@1, o);
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_07a_can_fail_rejected {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(dummyWithCode(1));
    }].error(^id(NSError *e){
        [ex1 fulfill];
        XCTAssertEqualObjects(@"1", e.localizedDescription);
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_09_async {
    id ex1 = [self expectationWithDescription:@""];
    
    __block int x = 0;
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }].then(^id(id nop){
        XCTAssertEqual(x, 0);
        x++;
        return nil;
    }).then(^id(id nop){
        XCTAssertEqual(x, 1);
        x++;
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    XCTAssertEqual(x, 2);
}

- (void)test_10_then_returns_resolved_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@10);
    }].then(^(id o){
        XCTAssertEqualObjects(@10, o);
        return [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
            resolve(@100);
        }];
    }).then(^id(id o){
        XCTAssertEqualObjects(@100, o);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_11_then_returns_pending_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }].then(^id(id nop){
        return fulfillLater();
    }).then(^id(id o){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_12_then_returns_recursive_promises {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];
    
    __block int x = 0;
    fulfillLater().then(^id(id nop){
        NSLog(@"1");
        XCTAssertEqual(x++, 0);
        return fulfillLater().then(^id(id nop){
            NSLog(@"2");
            XCTAssertEqual(x++, 1);
            return fulfillLater().then(^id(id nop){
                NSLog(@"3");
                XCTAssertEqual(x++, 2);
                return fulfillLater().then(^id(id nop){
                    NSLog(@"4");
                    XCTAssertEqual(x++, 3);
                    [ex2 fulfill];
                    return @"foo";
                });
            });
        });
    }).then(^id(id o){
                NSLog(@"5");
        XCTAssertEqualObjects(@"foo", o);
        XCTAssertEqual(x++, 4);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
    
    XCTAssertEqual(x, 5);
}

 - (void)test_13_then_returns_recursive_promises_that_fails {
     id ex1 = [self expectationWithDescription:@""];
     id ex2 = [self expectationWithDescription:@""];
     
     fulfillLater().then(^id(id nop){
         return fulfillLater().then(^id(id nop){
             return fulfillLater().then(^id(id nop){
                 return fulfillLater().then(^id(id nop){
                     [ex2 fulfill];
                     return dummy();
                 });
             });
         });
     }).then(^id(id nop){
         XCTFail();
         return nil;
     }).error(^id(NSError *e){
         XCTAssertEqualObjects(e.domain, CorePromiseErrorDomain);
         [ex1 fulfill];
         return nil;
     });

     [self waitForExpectationsWithTimeout:5 handler:nil];
 }

- (void)test_14_fail_returns_value {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }].then(^id(id nop){
        return [NSError errorWithDomain:@"a" code:1 userInfo:nil];
    }).error(^id(NSError *e){
        XCTAssertEqual(e.code, 1);
        return @2;
    }).then(^id(id o){
        XCTAssertEqualObjects(o, @2);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:5 handler:nil];
}

- (void)test_15_fail_returns_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@1);
    }].then(^id(id nop){
        return dummy();
    }).error(^id(id nop){
        return fulfillLater().then(^id(id nop){
            return @123;
        });
    }).then(^id(id o){
        XCTAssertEqualObjects(o, @123);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_23_add_another_fail_to_already_rejected {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];
    
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver  _Nonnull resolver) {
        resolver(dummyWithCode(23));
    }];
    
    promise.then(^id(id nop){
        XCTFail();
        return nil;
    }).error(^id(NSError *e){
        XCTAssertEqualObjects(e.localizedDescription, @"23");
        [ex1 fulfill];
        return nil;
    });

    promise.then(^id(id nop){
        XCTFail();
        return nil;
    }).error(^id(NSError *e){
        XCTAssertEqualObjects(e.localizedDescription, @"23");
        [ex2 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_25_then_plus_deferred_plus_GCD {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];
    id ex3 = [self expectationWithDescription:@""];
    
    fulfillLater().then(^id(id o){
        [ex1 fulfill];
        return fulfillLater().then(^id(id nop){
            return @YES;
        });
    }).then(^id(id o){
        XCTAssertEqualObjects(@YES, o);
        [ex2 fulfill];
        return nil;
    }).then(^id(id o){
        XCTAssertNil(o);
        [ex3 fulfill];
        return nil;
    }).error(^id(id nop){
        XCTFail();
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)test_26_promise_then_promise_fail_promise_fail {
    id ex1 = [self expectationWithDescription:@""];
    
    fulfillLater().then(^id(id nop){
        return fulfillLater().then(^id(id nop){
            return dummy();
        }).error(^id(id nop){
            return fulfillLater().then(^id(id nop){
                return dummy();
            });
        });
    }).then(^id(id nop){
        XCTFail();
        return nil;
    }).error(^id(id nop){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];}

- (void)test_27_eat_failure {
    id ex1 = [self expectationWithDescription:@""];
    
    fulfillLater().then(^id(id nop){
        return dummy();
    }).error(^id(id nop){
        return @YES;
    }).then(^id(id nop){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_28_deferred_rejected_catch_promise {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];

    rejectLater().error(^id(id nop){
        [ex1 fulfill];
        return fulfillLater();
    }).then(^id(id o){
        [ex2 fulfill];
        return nil;
    }).error(^id(id nop){
        XCTFail();
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_29_deferred_rejected_catch_promise {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];
    
    rejectLater().error(^id(id nop){
        [ex1 fulfill];
        return fulfillLater().then(^id(id nop){
            return dummy();
        });
    }).then(^id(id nop){
        XCTFail(@"1");
        return nil;
    }).error(^id(NSError *error){
        [ex2 fulfill];
        return nil;
    }).error(^id(id nop){
        XCTFail(@"2");
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_30_dispatch_returns_pending_promise {
    id ex1 = [self expectationWithDescription:@""];
    CorePromiseDispatch(^id(id nop){
        return fulfillLater();
    }).then(^id(id nop){
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_31_dispatch_returns_promise {
    id ex1 = [self expectationWithDescription:@""];
    CorePromiseDispatch(^id(id nop){
        return [CPPromise promiseWithValue:@1];
    }).then(^id(id o){
        XCTAssertEqualObjects(o, @1);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_32_return_primitive {
    id ex1 = [self expectationWithDescription:@""];
    __block void (^fulfiller)(id) = nil;
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        fulfiller = resolve;
    }].then(^id(id o){
        XCTAssertEqualObjects(o, @32);
        return @3;
    }).then(^id(id o){
        XCTAssertEqualObjects(@3, o);
        [ex1 fulfill];
        return nil;
    });
    fulfiller(@32);
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_33_return_nil {
    id ex1 = [self expectationWithDescription:@""];
    [CPPromise promiseWithValue:@1].then(^id(id o){
        XCTAssertEqualObjects(o, @1);
        return nil;
    }).then(^id(id nop){
        return nil;
    }).then(^id(id o){
        XCTAssertNil(o);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_33a_return_nil {
    id ex1 = [self expectationWithDescription:@""];
    id ex2 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithValue:@"HI"].then(^id(id o){
        XCTAssertEqualObjects(o, @"HI");
        [ex1 fulfill];
        return nil;
    }).then(^id(id o){
        return nil;
    }).then(^id(id o){
        [ex2 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_36_promise_with_value_nil {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithValue:nil].then(^id(id o){
        XCTAssertNil(o);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_42 {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithValue:@1].then(^id(id o){
        return fulfillLater();
    }).then(^id(id o){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_43_return_promise_from_itself {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *p = fulfillLater().then(^id(id o){ return @1; });
    p.then(^id(id o){
        return p;
    }).then(^id(id o){
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_44_reseal {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve(@123);
        resolve(@234);
    }].then(^id(id o){
        XCTAssertEqualObjects(o, @123);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_46_test_then_on {
    id ex1 = [self expectationWithDescription:@""];
    
    static NSOperationQueue* queue1 = nil;
    static NSOperationQueue* queue2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue1 = [[NSOperationQueue alloc] init];
        queue2 = [[NSOperationQueue alloc] init];
    });

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [CPPromise promiseWithValue:@1].thenOn(queue1, ^id(id o){
        XCTAssertFalse([NSThread isMainThread]);
        return dispatch_get_current_queue();
    }).thenOn(queue2, ^id(id q){
        XCTAssertFalse([NSThread isMainThread]);
        XCTAssertNotEqualObjects(q, dispatch_get_current_queue());
        [ex1 fulfill];
        return nil;
    });
#pragma clang diagnostic pop
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_47_finally_plus {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithValue:@1].then(^id(id o){
        return @1;
    }).finally(^(id o){
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_49_finally_negative_later {
    id ex1 = [self expectationWithDescription:@""];
    __block int x = 0;
    
    [CPPromise promiseWithValue:@1].then(^id(id o){
        XCTAssertEqual(++x, 1);
        return dummy();
    }).error(^id(id o){
        XCTAssertEqual(++x, 2);
        return nil;
    }).then(^id(id o){
        XCTAssertEqual(++x, 3);
        return nil;
    })
    .finally( ^(id o) {
        NSLog( @"" );
        XCTAssertEqual(++x, 4);
        [ex1 fulfill];
        NSLog( @"" );
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_50_fulfill_with_pending_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        
        resolve( fulfillLater()
                .then( ^id(id o) {
                    return @"HI";
        }) );
        
    }].then(^id(id hi){
        XCTAssertEqualObjects(hi, @"HI");
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_51_fulfill_with_fulfilled_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        resolve([CPPromise promiseWithValue:@1]);
    }].then(^id(id o){
        XCTAssertEqualObjects(o, @1);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_52_fulfill_with_rejected_promise {  //NEEDEDanypr
    id ex1 = [self expectationWithDescription:@""];
    fulfillLater().then(^id(id o){
        return [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
            resolve([CPPromise promiseWithValue:dummy()]);
        }];
    }).error(^id(NSError *err){
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:20 handler:nil];
}

- (void)test_53_return_rejected_promise {
    id ex1 = [self expectationWithDescription:@""];
    fulfillLater().then(^id(id o){
        return @1;
    }).then(^id(id o){
        return [CPPromise promiseWithValue:dummy()];
    }).error(^id(id o){
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_54_reject_with_rejected_promise {
    id ex1 = [self expectationWithDescription:@""];
    
    [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        id err = [NSError errorWithDomain:@"a" code:123 userInfo:nil];
        resolve([CPPromise promiseWithValue:err]);
    }].error(^id(NSError *err){
        XCTAssertEqual(err.code, 123);
        [ex1 fulfill];
        return nil;
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_58_just_finally {
    id ex1 = [self expectationWithDescription:@""];
    
    CPPromise *promise = fulfillLater().then(^id(id o){
        return nil;
    });
    
    promise.finally(^(id o){
        [ex1 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
    
    id ex2 = [self expectationWithDescription:@""];
    
    promise.finally(^(id o){
        [ex2 fulfill];
    });
    
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

//- (void)test_nil_block {
//    [CPPromise promiseWithValue:@1].then(nil);
//    [CPPromise promiseWithValue:@1].thenOn(nil, nil);
//    [CPPromise promiseWithValue:@1].error(nil);
//    [CPPromise promiseWithValue:@1].finally(nil);
//    [CPPromise promiseWithValue:@1].finallyOn(nil, nil);
//}

@end


