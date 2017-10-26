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

@import Foundation;
#import <CorePromise/CorePromise.h>
@import XCTest;


@interface JoinTests: XCTestCase @end @implementation JoinTests

- (void)test_73_join {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];

    __block void (^fulfiller)(id) = nil;
    CPPromise *promise = [CPPromise promiseWithResolverBlock:^(CPPromiseResolver resolve) {
        fulfiller = resolve;
    }];

    CorePromiseJoin(@[
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:1 userInfo:nil]],
              promise,
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:2 userInfo:nil]]
              ]).then(^id(id nop){
        XCTFail();
        return nil;
    }).error(^id(NSError *error){
        id promises = error.userInfo[CorePromiseJoinPromisesKey];

        int cume = 0, cumv = 0;

        for (CPPromise *promise in promises) {
            if ([promise.value isKindOfClass:[NSError class]]) {
                cume |= [promise.value code];
            } else {
                cumv |= [promise.value unsignedIntValue];
            }
        }

        XCTAssertTrue(cumv == 4);
        XCTAssertTrue(cume == 3);

        [ex1 fulfill];
        return nil;
    });
    fulfiller(@4);
    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)test_74_join_no_errors {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[
              [CPPromise promiseWithValue:@1],
              [CPPromise promiseWithValue:@2]
              ]).then(^id(NSArray *values) {
        XCTAssertEqualObjects(values, (@[@1, @2]));
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}


- (void)test_75_join_no_success {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:1 userInfo:nil]],
              [CPPromise promiseWithValue:[NSError errorWithDomain:@"dom" code:2 userInfo:nil]],
              ]).then(^id(id nop){
        XCTFail();
        return nil;
    }).error(^id(NSError *error){
        XCTAssertNotNil(error);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

- (void)test_76_join_fulfills_if_empty_input {
    XCTestExpectation *ex1 = [self expectationWithDescription:@""];
    CorePromiseJoin(@[]).then(^id(id a){
        XCTAssertEqualObjects(@[], a);
        [ex1 fulfill];
        return nil;
    });
    [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
